# Dev Journal

Stashing notes and stories around the development of the game. It's a semi-secret project, so we're not sharing the details with the world yet. But we're sharing the journey.

## 08 August 2023

Had my last wisdom tooth removed (the last one was removed a week ago), and got an infection. Or at least my body started to react and fight something by giving me a fever, heavy head and a sore throat.

Couldn't really work on anything no matter how much I wanted to. So I decided to write this journal. It helped, but also I took a peek at the MVP for the pokemon algorith again. Somehow, even though I double checked my solution multiple times and even written it from the scratch (thanks, Copilot!) - the numbers didn't work. The resulting damage was always around 1-3 HP, which is not what I expected. If a Capy has 50 HP, hitting it with 2 DMG per turn would take 25 turns to win, that's a lot, and not what we planned. But even with this, the move change wouldn't do a thing, so even at level 100 Capy hit with 2 DMG.

Randomly wrote to Alberto and asked for his help to debug. Surprisingly, he was online and even tried to help me tune the solution. After 40 minutes of useless trial and error I looked at the formula more carefully and discovered that I mistook Move Power for Type Effectiveness, mostly because the paper I was referencing did not mention anything about the Move Power and I expected the value to be in range 0-2, while in reality it's 10-100.

Anyways, it's a first problem and a first success. Having finally solved this, I have some energy to implement this solution in Move; and why make it too specific - we can make it generic and available to everyone.

- Damir


## 07 August 2023

Told the idea to John, we got one more man on the team. While it's not fully clear how security skills can be used in development, having a security expert on the team is a good thing - plus John is a good friend and amazing person.

- Damir


## 02 August 2023

Met Ben from Marketing. Ben is a content producer, he does great things and interviews and some fancy content. He's also looking into using AI for content generation. So I decided to tell him about the idea and see if he's interested in helping us with the content. Why not create a story for the game from the start? If we're good, then we can show what a small group of humans can achieve in on a short timeframe. People loves stories, we love stories, and Ben is the person who can help us get there.

He loved the idea and agreed to help! Worth mentioning that I had doubts on whether we should tell our idea to someone from the Marketing or Product - after all it's a semi-secret dev initiative, we're trying to keep it to ourselves for now. But having Ben help us in an area we (developers!!!) don't have much experience in is a great thing.

- Damir


## July 2023

During my trip and any available time that I could spend on thinking in this direction I was trying to crack my head around the problem of how to create a game that would be fun to play and at the same time would be a good example of how to use the SuiFrens framework.

By that time we've been multiple rounds of ideas together with Alberto and Manos. The ideas were radical - let's build Heroes-like turn based multiplayer strategy game with castles and buildings; or, perhaps, a pokemon tournament - to make it even more Pokemon-y. Single battles were no longer there - it's boring - and having a single battle in an environment where we can't get cheap and easy to use randomness will probably be a bad idea due to predictability. As soon as money is involved, predictability doesn't work.

---

But apart from that I started looking into game development - how people build games, what they build, what's their success story, what are the cool tiny details that made players choose or favor this game.

And one detail that we should have thought from the start was graphics and music. We're developers - it's an alien domain for us.

---

Important thought: the perfect game is a mix of a good balance with enjoyable gameplay and a good story. Story we have - and it's a challenge game, so not much can be done; but balance is of utmost importance. And the graphics... well, we can't do graphics.

- Damir


## June 2023

When we were open-sourcing the SuiFrens code I happened to be in London. And just showing the code wasn't enough in my opinion, I wanted to how how the code could be used, and decided to create two small packages to illustrate how an imported module is used.

One was "genes" viewer - simple show&tell-something, too simple to describe. However, the second one was "capy fight" - a simple algorithm to calculate which capy wins if they were fighting against each other. I wanted to do "rounds" - so that the battle is not calculated based on the first attack but on a series of attacks in turns.

While my attempt failed and the algorithm I created was too dumb (I'm a novice after all), I decided to ask our researcher - Alberto - if he can help me with the algorithm (researcher -> papers -> math???). His suggestion right away was to use Pokemon algorithm: it's been out there for decades, it's well known, and it's a good starting point.

And that was it. The beginning of the journey.

- Damir
