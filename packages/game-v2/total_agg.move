module game::arena {
    use std::vector;
    use std::option::{Self, Option};
    use sui::tx_context::TxContext;
    use sui::kiosk::{Self, Kiosk, KioskOwnerCap};
    use sui::object::{Self, ID, UID};
    use sui::clock::{Self, Clock};
    use sui::hash::blake2b256;
    use sui::transfer;
    use sui::bcs;
    use game::battle;
    use game::player::{Self, Player};
    use pokemon::stats::{Self, Stats};
    friend game::the_game;
    const EArenaNotReady: u64 = 0;
    const EArenaOver: u64 = 1;
    const EAnotherPlayerNotReady: u64 = 2;
    const EMoveAlreadySubmitted: u64 = 4;
    const EUnknownSender: u64 = 5;
    const EInvalidCommitment: u64 = 6;
    struct Arena has key {
        id: UID,
        seed: vector<u8>,
        round: u8,
        game_id: ID,
        p1: Option<ActivePlayer>,
        p2: Option<ActivePlayer>,
        last_action_timestamp_ms: u64,
        last_action_user: ID,
        winner: Option<ID>
    }
    struct ActivePlayer has store, drop {
        stats: Stats,
        kiosk_id: ID,
        next_attack: Option<vector<u8>>,
        next_round: u8,
        player: Player
    }
    public fun create_arena(
        game_id: ID, p1: Player, p2: Player, ctx: &mut TxContext
    ): ID {
        let id = object::new(ctx);
        let arena_id = object::uid_to_inner(&id);
        let seed = blake2b256(&bcs::to_bytes(&arena_id));
        transfer::share_object(Arena {
            id,
            seed,
            game_id,
            round: 0,
            p1: add_player(p1),
            p2: add_player(p2),
            last_action_timestamp_ms: 0,
            last_action_user: arena_id,
            winner: option::none()
        });
        arena_id
    }
    entry fun commit(
        self: &mut Arena,
        cap: &KioskOwnerCap,
        commitment: vector<u8>,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        assert!(!is_over(self), EArenaOver);
        assert!(still_time(self, clock), EArenaOver);
        assert!(!is_any_player_down(self), EArenaOver);
        let kiosk_id = kiosk::kiosk_owner_cap_for(cap);
        let player = if (kiosk_id == option::borrow(&self.p1).kiosk_id) {
            option::borrow_mut(&mut self.p1)
        } else if (kiosk_id == option::borrow(&self.p2).kiosk_id) {
            option::borrow_mut(&mut self.p2)
        } else {
        };
        assert!(option::is_none(&player.next_attack), EMoveAlreadySubmitted);
        option::fill(&mut player.next_attack, commitment);
        self.last_action_timestamp_ms = clock::timestamp_ms(clock);
        self.last_action_user = kiosk_id;
    }
    entry fun reveal(
        self: &mut Arena,
        cap: &KioskOwnerCap,
        player_move: u8,
        salt: vector<u8>,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        assert!(!is_over(self), EArenaOver);
        assert!(still_time(self, clock), EArenaOver);
        assert!(!is_any_player_down(self), EArenaOver);
        let kiosk_id = kiosk::kiosk_owner_cap_for(cap);
        let (attacker, defender) = if (is_player_one(self, kiosk_id)) {
            (
                option::borrow_mut(&mut self.p1),
                option::borrow_mut(&mut self.p2)
            )
        } else if (is_player_two(self, kiosk_id)) {
            (
                option::borrow_mut(&mut self.p2),
                option::borrow_mut(&mut self.p1)
            )
        } else {
        };
        assert!(option::is_some(&attacker.next_attack), EAnotherPlayerNotReady);
        assert!(attacker.next_round == self.round, EMoveAlreadySubmitted);
        let commitment = vector[ player_move ];
        vector::append(&mut commitment, salt);
        let commitment = blake2b256(&commitment);
        let next_attack = option::extract(&mut attacker.next_attack);
        assert!(&commitment == &next_attack, EInvalidCommitment);
        battle::attack(
            &attacker.stats,
            &mut defender.stats,
            (player_move as u64),
            hit_rng(commitment, clock::timestamp_ms(clock), self.round),
        );
        attacker.next_round = self.round + 1;
        let next_round_cond = option::is_none(&defender.next_attack)
            && (defender.next_round == (self.round + 1));
        self.last_action_timestamp_ms = clock::timestamp_ms(clock);
        self.last_action_user = kiosk_id;
        if (next_round_cond) {
            self.round = self.round + 1;
        };
    }
    public(friend) fun wrap_up(self: &mut Arena, kiosk: &Kiosk): (Player, bool) {
        let ActivePlayer {
            player,
            stats: _,
            kiosk_id: _,
            next_attack: _,
            next_round: _,
        } = if (is_player_one(self, object::id(kiosk))) {
            option::extract(&mut self.p1)
        } else if (is_player_two(self, object::id(kiosk))) {
            option::extract(&mut self.p2)
        } else {
        };
        (player, true)
    }
    public fun is_over(self: &Arena): bool {
        option::is_none(&self.p1) || option::is_none(&self.p2)
    }
    public fun still_time(_self: &Arena, _clock: &Clock): bool {
        true
    }
    public fun game_id(self: &Arena): ID { self.game_id }
    public fun round(self: &Arena): u8 { self.round }
    fun is_any_player_down(self: &Arena): bool {
        let p1 = option::borrow(&self.p1);
        let p2 = option::borrow(&self.p2);
        stats::hp(&p1.stats) == 0 || stats::hp(&p2.stats) == 0
    }
    fun is_player_one(self: &Arena, kiosk_id: ID): bool {
        if(option::is_none(&self.p1)) {
            false
        }else {
            option::borrow(&self.p1).kiosk_id == kiosk_id
        }
    }
    fun is_player_two(self: &Arena, kiosk_id: ID): bool {
        if(option::is_none(&self.p2)) {
             false
        }else {
            option::borrow(&self.p2).kiosk_id == kiosk_id
        }
    }
    fun add_player(player: Player): Option<ActivePlayer> {
        option::some(ActivePlayer {
            stats: *player::stats(&player),
            kiosk_id: player::kiosk(&player),
            next_attack: option::none(),
            next_round: 0,
            player
        })
    }
    fun hit_rng(seed: vector<u8>, timestamp_ms: u64, round: u8): u8 {
        let seed = bcs::to_bytes(&vector[
            bcs::to_bytes(&timestamp_ms),
            bcs::to_bytes(&seed),
        ]);
        let seed = blake2b256(&seed);
        let value = *vector::borrow(&seed, (round as u64));
        ((value % (255 - 217)) + 217)
    }
}
module game::battle {
    use std::vector;
    use pokemon::pokemon_v1 as pokemon;
    use pokemon::stats::{Self, Stats};
    const EWrongMove: u64 = 0;
    const TOTAL_MOVES: u64 = 8;
    const STARTER_MOVES: vector<vector<u8>> = vector[
        vector[ 0, 1, 6, 2 ],
        vector[ 2, 3, 0, 4 ],
        vector[ 4, 5, 2, 6 ],
        vector[ 6, 7, 4, 0 ],
    ];
    const MOVES_SPECIAL: vector<bool> = vector[
    ];
    const MOVES_TYPES: vector<u8> = vector[
    ];
    const MOVES_POWER: vector<u8> = vector[
    ];
    const MOVES_EFFECTIVENESS: vector<vector<u64>> = vector[
        vector[10, 20, 5, 10],
        vector[5, 10, 20, 10],
        vector[20, 5, 10, 10],
        vector[10, 5, 10, 20]
    ];
    const STAB_BONUS: u64 = 15;
    const EFF_SCALING: u64 = 10;
    public fun attack(
        attacker: &Stats, defender: &mut Stats, move_: u64, rng: u8
    ): (u64, u64, bool) {
        assert!(move_ < TOTAL_MOVES, EWrongMove);
        let move_type = *vector::borrow(&MOVES_TYPES, move_);
        let move_power = *vector::borrow(&MOVES_POWER, move_);
        let is_special = *vector::borrow(&MOVES_SPECIAL, move_);
        let attacker_type = (*vector::borrow(&stats::types(attacker), 0) as u64);
        let defender_type = (*vector::borrow(&stats::types(defender), 0) as u64);
        let raw_damage = if (is_special) {
            pokemon::special_damage(attacker, defender, move_power, rng)
        } else {
            pokemon::physical_damage(attacker, defender, move_power, rng)
        };
        let move_effectiveness = *vector::borrow(&MOVES_EFFECTIVENESS, (move_type as u64));
        let effectiveness = *vector::borrow(&move_effectiveness, defender_type);
        raw_damage = raw_damage * effectiveness / EFF_SCALING;
        if (move_ == attacker_type) {
            raw_damage = raw_damage * STAB_BONUS / EFF_SCALING;
        };
        stats::decrease_hp(defender, raw_damage);
        (raw_damage, effectiveness, move_ == attacker_type)
    }
    public fun starter_moves(type: u8): vector<u8> {
        assert!(type < 4, EWrongMove);
        *vector::borrow(&STARTER_MOVES, (type as u64))
    }
}
module game::matchmaker {
    use std::option::{Self, Option};
    use sui::tx_context::{fresh_object_address, TxContext};
    use sui::kiosk::{Self, KioskOwnerCap};
    use sui::object::{Self, ID, UID};
    use sui::dynamic_field as df;
    use sui::transfer;
    use game::player::{Self, Player};
    use game::arena::create_arena;
    const ENoSearch: u64 = 0;
    const ENotFromKiosk: u64 = 1;
    friend game::the_game;
    struct MatchPool has key, store {
        id: UID,
        request: Option<Player>
    }
    fun init(ctx: &mut TxContext) {
        transfer::share_object(MatchPool {
            id: object::new(ctx),
            request: option::none(),
        });
    }
    public fun find_or_create_match(
        self: &mut MatchPool,
        player: Player,
        ctx: &mut TxContext
    ): ID {
        if (option::is_some(&self.request)) {
            let opponent = option::extract(&mut self.request);
            let match_id = df::remove(&mut self.id, player::kiosk(&opponent));
            let arena_id = create_arena(match_id, player, opponent, ctx);
            df::add(&mut self.id, match_id, arena_id);
            match_id
        } else {
            let match_id = new_id(ctx);
            df::add(&mut self.id, player::kiosk(&player), match_id);
            option::fill(&mut self.request, player);
            match_id
        }
    }
    public(friend) fun cancel_search(
        self: &mut MatchPool,
        cap: &KioskOwnerCap,
        _ctx: &mut TxContext
    ): Player {
        assert!(option::is_some(&self.request), ENoSearch);
        let player: Player = option::extract(&mut self.request);
        df::remove<ID, ID>(&mut self.id, player::kiosk(&player));
        assert!(player::kiosk(&player) == kiosk::kiosk_owner_cap_for(cap), ENotFromKiosk);
        player
    }
    public(friend) fun try_marker_rebate(
        self: &mut MatchPool,
        match_id: ID,
    ) {
        if (df::exists_(&self.id, match_id)) {
            let _: ID = df::remove(&mut self.id, match_id);
        }
    }
    fun new_id(ctx: &mut TxContext): ID {
        object::id_from_address(fresh_object_address(ctx))
    }
}
module game::player {
    use std::vector;
    use std::option::{Self, Option};
    use sui::clock::{Self, Clock};
    use sui::tx_context::TxContext;
    use sui::object::ID;
    use pokemon::stats::{Self, Stats};
    const MEDIAN: u8 = 35;
    friend game::the_game;
    const ENotBanned: u64 = 0;
    const EStillBanned: u64 = 1;
    struct Player has store, drop {
        stats: Stats,
        kiosk: ID,
        banned_until: Option<u64>,
        moves: vector<u8>,
        rank: u64
    }
    public(friend) fun new(
        kiosk: ID,
        type: u8,
        moves: vector<u8>,
        seed: vector<u8>,
        _ctx: &mut TxContext
    ): Player {
        Player {
            kiosk,
            stats: generate_stats(type, seed),
            banned_until: option::none(),
            rank: 1200
        }
    }
    public fun ban_player(
        self: &mut Player,
        clock: &Clock,
        duration_minutes: u64,
        _ctx: &mut TxContext
    ) {
        assert!(option::is_none(&self.banned_until), EStillBanned);
        let banned_until = clock::timestamp_ms(clock) + duration_minutes * 60 * 1000;
        self.banned_until = option::some(banned_until);
    }
    public fun remove_ban(
        self: &mut Player,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        assert!(option::is_some(&self.banned_until), ENotBanned);
        let banned_until = option::extract(&mut self.banned_until);
        assert!(clock::timestamp_ms(clock) >= banned_until, ENotBanned);
    }
    public fun stats(self: &Player): &Stats { &self.stats }
    public fun kiosk(self: &Player): ID { self.kiosk }
    public fun banned_until(self: &Player): Option<u64> { self.banned_until }
    public fun is_banned(self: &Player): bool {
        option::is_some(&self.banned_until)
    }
    fun generate_stats(type: u8, seed: vector<u8>): Stats {
        let level = 1;
        stats::new(
            10 + smooth(*vector::borrow(&seed, 0)),
            smooth(*vector::borrow(&seed, 1)),
            smooth(*vector::borrow(&seed, 2)),
            smooth(*vector::borrow(&seed, 3)),
            smooth(*vector::borrow(&seed, 4)),
            smooth(*vector::borrow(&seed, 5)),
            level,
            vector[ type ]
        )
    }
    fun smooth(value: u8): u8 {
        let value = ((value % MEDIAN) + MEDIAN) / 2;
        if (value < 10) {
            10
        } else {
            value
        }
    }
}
module game::the_game {
    use std::option;
    use sui::bcs;
    use sui::bag;
    use sui::object::{Self, ID};
    use sui::kiosk_extension as ext;
    use sui::tx_context::{Self, TxContext};
    use sui::kiosk::{Self, Kiosk, KioskOwnerCap};
    use game::player;
    use game::battle;
    use game::arena::{Self, Arena};
    use game::matchmaker::{Self, MatchPool};
    const EExtensionNotInstalled: u64 = 0;
    const EPlayerAlreadyExists: u64 = 1;
    const ENoPlayer: u64 = 2;
    const EPlayerIsPlaying: u64 = 3;
    const ENotOwner: u64 = 4;
    const EInvalidUserType: u64 = 5;
    const EPlayerIsBanned: u64 = 6;
    const EWrongArena: u64 = 7;
    const EWrongKiosk: u64 = 8;
    struct PlayerKey has store, copy, drop {}
    struct MatchKey has store, copy, drop {}
    struct Game has drop {}
    const PERMISSIONS: u128 = 2;
    public fun add(kiosk: &mut Kiosk, cap: &KioskOwnerCap, ctx: &mut TxContext) {
        ext::add(Game {}, kiosk, cap, PERMISSIONS, ctx)
    }
    entry fun new_player(
        kiosk: &mut Kiosk,
        cap: &KioskOwnerCap,
        type: u8,
        ctx: &mut TxContext
    ) {
        assert!(type < 4, EInvalidUserType);
        assert!(kiosk::has_access(kiosk, cap), ENotOwner);
        assert!(ext::is_installed<Game>(kiosk), EExtensionNotInstalled);
        assert!(!has_player(kiosk), EPlayerAlreadyExists);
        let moves = battle::starter_moves(type);
        let rand_source = bcs::to_bytes(&tx_context::fresh_object_address(ctx));
        let player = player::new(object::id(kiosk), type, moves, rand_source, ctx);
        let storage = ext::storage_mut(Game {}, kiosk);
        bag::add(storage, PlayerKey {}, option::some(player))
    }
    entry fun play(
        kiosk: &mut Kiosk,
        cap: &KioskOwnerCap,
        matches: &mut MatchPool,
        ctx: &mut TxContext
    ) {
        assert!(kiosk::has_access(kiosk, cap), ENotOwner);
        assert!(ext::is_installed<Game>(kiosk), EExtensionNotInstalled);
        assert!(has_player(kiosk), ENoPlayer);
        assert!(!is_playing(kiosk), EPlayerIsPlaying);
        let storage = ext::storage_mut(Game {}, kiosk);
        let player = option::extract(bag::borrow_mut(storage, PlayerKey {}));
        assert!(!player::is_banned(&player), EPlayerIsBanned);
        let match_id = matchmaker::find_or_create_match(matches, player, ctx);
        bag::add(storage, MatchKey {}, match_id)
    }
    entry fun clear_arena(
        kiosk: &mut Kiosk,
        arena: &mut Arena,
        cap: &KioskOwnerCap,
        _matches: &mut MatchPool,
        _ctx: &mut TxContext
    ) {
        assert!(kiosk::has_access(kiosk, cap), ENotOwner);
        assert!(ext::is_installed<Game>(kiosk), EExtensionNotInstalled);
        assert!(has_player(kiosk), ENoPlayer);
        assert!(is_playing(kiosk), EPlayerIsPlaying);
        let (player, _is_winner) = arena::wrap_up(arena, kiosk);
        let storage = ext::storage_mut(Game {}, kiosk);
        let match_id = bag::remove(storage, MatchKey {});
        assert!(arena::game_id(arena) == match_id, EWrongArena);
        assert!(player::kiosk(&player) == kiosk::kiosk_owner_cap_for(cap), EWrongKiosk);
        option::fill(bag::borrow_mut(storage, PlayerKey {}), player);
    }
    entry fun cancel_search(
        kiosk: &mut Kiosk,
        matches: &mut MatchPool,
        cap: &KioskOwnerCap,
        ctx: &mut TxContext
    ) {
        assert!(kiosk::has_access(kiosk, cap), ENotOwner);
        assert!(ext::is_installed<Game>(kiosk), EExtensionNotInstalled);
        assert!(has_player(kiosk), ENoPlayer);
        assert!(is_playing(kiosk), EPlayerIsPlaying);
        let player = matchmaker::cancel_search(matches, cap, ctx);
        let storage = ext::storage_mut(Game {}, kiosk);
        let _: ID = bag::remove(storage, MatchKey {});
        option::fill(bag::borrow_mut(storage, PlayerKey {}), player);
    }
    public fun has_player(kiosk: &Kiosk): bool {
        ext::is_installed<Game>(kiosk)
            && bag::contains(ext::storage(Game {}, kiosk), PlayerKey {})
    }
    public fun is_playing(kiosk: &Kiosk): bool {
        assert!(has_player(kiosk), ENoPlayer);
        bag::contains(ext::storage(Game {}, kiosk), MatchKey {})
    }
}
module pokemon::pokemon_v1 {
    use pokemon::stats::{Self, Stats};
    const EIncorrectRandomValue: u64 = 0;
    const EIncorrectMovePower: u64 = 1;
    public fun physical_damage(
        attacker: &Stats,
        defender: &Stats,
        move_power: u8,
        random: u8,
    ): u64 {
        assert!(random >= 217 && random <= 255, EIncorrectRandomValue);
        assert!(move_power > 0, EIncorrectMovePower);
        damage(
            (stats::level(attacker) as u64),
            (stats::attack(attacker) as u64),
            (stats::defense(defender) as u64),
            (move_power as u64),
            (random as u64),
            stats::scaling(),
        )
    }
    public fun special_damage(
        attacker: &Stats,
        defender: &Stats,
        move_power: u8,
        random: u8,
    ): u64 {
        assert!(random >= 217 && random <= 255, EIncorrectRandomValue);
        assert!(move_power > 0, EIncorrectMovePower);
        damage(
            (stats::level(attacker) as u64),
            (stats::special_attack(attacker) as u64),
            (stats::special_defense(defender) as u64),
            (move_power as u64),
            (random as u64),
            stats::scaling(),
        )
    }
    fun damage(
        level: u64,
        attack: u64,
        defence: u64,
        move_power: u64,
        random: u64,
        scaling: u64,
    ): u64 {
        let lvl_mod = (2 * level * 1 / 5) + (2);
        let atk_def = (scaling * attack) / defence;
        let result  = (lvl_mod * move_power * atk_def / 50) + (2 * scaling);
        let rnd_val = (scaling * random) / 255;
        let eff_val = (1);
        (result * rnd_val * eff_val / scaling)
    }
    #[test]
    fun test_physical() {
        let capy_one = stats::new(45, 49, 49, 65, 65, 45, 13, vector[]);
        let capy_two = stats::new(40, 60, 30, 31, 31, 70, 10, vector[]);
        let _damage = physical_damage(&capy_one, &capy_two, 40, 217);
        let _damage = physical_damage(&capy_two, &capy_one, 35, 230);
    }
}
module pokemon::stats {
    const EIncorrectLevel: u64 = 0;
    const SCALING_FACTOR: u64 = 1_000_000_00;
    struct Stats has copy, store, drop {
        hp: u64,
        attack: u8,
        defense: u8,
        special_attack: u8,
        special_defense: u8,
        speed: u8,
        level: u8,
        types: vector<u8>
    }
    public fun new(
        hp: u8,
        attack: u8,
        defense: u8,
        special_attack: u8,
        special_defense: u8,
        speed: u8,
        level: u8,
        types: vector<u8>,
    ): Stats {
        assert!(level <= 100, EIncorrectLevel);
        Stats {
            hp: (hp as u64) * SCALING_FACTOR,
            attack,
            defense,
            special_attack,
            special_defense,
            speed,
            level,
            types,
        }
    }
    public fun scaling(): u64 { SCALING_FACTOR }
    public fun hp(stat: &Stats): u64 { stat.hp }
    public fun attack(stat: &Stats): u8 { stat.attack }
    public fun defense(stat: &Stats): u8 { stat.defense }
    public fun special_attack(stat: &Stats): u8 { stat.special_attack }
    public fun special_defense(stat: &Stats): u8 { stat.special_defense }
    public fun speed(stat: &Stats): u8 { stat.speed }
    public fun level(stat: &Stats): u8 { stat.level }
    public fun types(stat: &Stats): vector<u8> { stat.types }
    public fun decrease_hp(stat: &mut Stats, value: u64) {
        if (value > stat.hp) {
            stat.hp = 0;
        } else {
            stat.hp = stat.hp - value;
        }
    }
    public fun level_up(stat: &mut Stats) {
        stat.level = stat.level + 1;
    }
}
