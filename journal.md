# Dev Journal

Stashing notes and stories around the development of the game. It's a semi-secret project, so we're not sharing the details with the world yet. But we're sharing the journey.

## 25 August - Friday Night

Got stuck implementing multiplayer functionality. Each time when there's a very inconvient (in blockchain / development terms) case, I just lag - can't move, can't progress, everything is just super annoying. Every message system that requires 2 fields - one for each of the players makes me vomit. It would be great to find a way to encode the fighting logic in an elegant way but I haven't discovered one yet. Perhaps, there's something I can do as an exercise - build a simpler game prototype where players move after each other, and that would shed some light on how to implement multiplayer functionality.

- Damir

## 19-20 August 2023 - Weekend

Finally got some time to myself to work on the game. With big Kiosk thing in and the new cohort (Kiosk-only) out, I can finally focus on the capy fighting again, especially since we now know that Capys will live in Kiosks - that adds constraints, but gives us a boost - we can utilize Kiosk extensions and build a game around Kiosks.

Having a whole day to myself gives enough space for thoughts, and I had some time to think of how we'll implement the Kiosk Extension, not just to think but also to implement and record the implementation! I think most of developers don't feel comfortable coding "on record", and I'm no exception; but once started, I realized that having a commitment like this boosts my chances to fight ADHD. Well, anyways, the result is dope, I really enjoyed the process and have proven that it's doable, it can be fun, and you don't really need to talk - documentation does the job.

---

My Pixel Art journey continues and since I've decided to draw most of the art and assets for the game myself, I really need to rush working on them (as soon as we know what's needed ofc). In Paris I bought this book "A Dictionary of Color Combinations" - it's in Japanese, but the color names in English, it's a nice catalogue of colors in traditional Japanese designs and paintings grouped by months, types of design (eg kimono or a carpet). And since the moment I bought it I wanted to use it for the color scheme of the game.

Unfortunately, I wasn't able to find a digital version, so the only version I have is paper. And it's not very convient to use it - even more - the colors are in CMYK and most of the pixel art applications use RGB; so finding the right combination, then looking through the color codes (and searching these colors), and only then converting them to a palette is a pain. So I decided to create a small utility to help me with this. Now we have GMP palette generator in our codebase - small but nice achievement. One less reason to procrastinate.

- Damir

## 17 August 2023

Decided to get back to the game again. For some reason I tend to think about cool graphics and UIs and how users will interact with the app but we haven't even implemented the pokemon algorithm yet.

While UIs and Web is too hard, CLI is something I can enjoy building, and using a keyboard for tests is so much better than mouse. From the start I've built a way to test a random scenario but also to reproduce this scenario if the tester saves the seed. This way we can store the best and calibrate the balance according to critical values.

...and it's a success - for 3 hours straight I couldn't stop playing with a bot that was fighting against me. Each time random; and sometimes I would repeat the game to try a different move or check if the STAB (Same type attach bonus) works as expected.

Not in the best shape today; but I'm happy with the progress.

- Damir

## 10 August 2023

When I pitched the idea to my manager he raised the question of funding - how can we make sure the players don't run out of money while playing? Is there a way for us to create an in-game economy that would "loop-in" the profits made by the game to fund the players? Just saying, something to think about - it can be a critical issue.

Apart from that started trying out pixi.js - an engine that allows building 2D games in browser. Not much to say yet, we're just scratching the surface. As a first example of an app I created a custom font inspired by the "Space Invaders" (enhanced with some shadow), the font is converted into a sprite sheet and then used to render text. If someone asked me a month ago if I know what the spritesheets are I would have said "no", but now I know. And I know how to create and use them. Funny times!

The best tutorial on pixi.js is this one: https://www.pixijselementals.com/#introduction, the guy knows what he's doing and I just love the personality in his writing.

- Damir

## 09 August 2023

The dopamine rush from solving the formula mystery was so strong that I couldn't stop myself from implementing the solution in Move. Even though I am completely tired and can't really do anything; multiple takes, 10 minutes is the max I can do per one attempt. But I did it. We now have a working solution for the pokemon algorithm in Move.

Originally we planned to use `u8` as the type for everything, but now I think that having `u64` and upscale the values to keep precision is a better idea. We can always downscale the values to `u8` when we need to, but we can't upscale them back.

There's more to the algorithm than just the damage calculation, but I think we can leave it for later. The damage calculation is the most important part, and we can get back to STAB (Same Type Attack Bonus) and other things later - building a matrix of type effectiveness is a challenge, but it would help to first settle on the moves we want to use for Capys.

...and we still haven't figured what to do with bullsharks.

- Damir

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
