-- Content bank — the global library, batch 1 (docs/CONTENT_BANK.md §1.3).
--
-- Authored through Claude Code at dev time, committed as a seed so the
-- kid-safety review is the COMMIT review (the content is right here, in
-- plain SQL, for a human to read before it ships). No runtime model, no
-- vendor key, no per-play cost. The table is a LIVING DOCUMENT: future
-- batches land as additional seed migrations.
--
-- All rows are GLOBAL (space_id IS NULL) so they reach every program via
-- the `global_content` sync stream, and `source = 'ai'` for honest
-- provenance (AI-authored, human-reviewed at commit). `payload` matches
-- the shape each activity reads; `fingerprint` follows the same scheme the
-- in-app curated floor uses (lowercase of the key field) so a banked row
-- that duplicates a curated seed collapses at the bank's load-time de-dupe.
--
-- Dollar-quoted ($$…$$) strings so apostrophes/quotes inside the content
-- need no escaping. ON CONFLICT DO NOTHING so re-applying is harmless and
-- a row that collides with an earlier batch (same kind+fingerprint) is
-- simply skipped (uniqueness is the bank's job — §4).
--
-- Ages 4–12, afterschool-appropriate: wholesome, inclusive, no violence /
-- fear / romance / politics. Fact-or-Fib statements are factually accurate.

-- ── This-or-That (would-you-rather pairs) ────────────────────────────────
insert into public.content_items (space_id, kind, payload, fingerprint, source) values
  (null, 'this_or_that', $${"a":"Pizza","b":"Sushi"}$$, $$pizza|sushi$$, 'ai'),
  (null, 'this_or_that', $${"a":"Beach day","b":"Forest hike"}$$, $$beach day|forest hike$$, 'ai'),
  (null, 'this_or_that', $${"a":"Cookies","b":"Ice cream"}$$, $$cookies|ice cream$$, 'ai'),
  (null, 'this_or_that', $${"a":"Ride a bike","b":"Ride a scooter"}$$, $$ride a bike|ride a scooter$$, 'ai'),
  (null, 'this_or_that', $${"a":"Robots","b":"Dinosaurs"}$$, $$robots|dinosaurs$$, 'ai'),
  (null, 'this_or_that', $${"a":"Superheroes","b":"Wizards"}$$, $$superheroes|wizards$$, 'ai'),
  (null, 'this_or_that', $${"a":"Build with blocks","b":"Paint a picture"}$$, $$build with blocks|paint a picture$$, 'ai'),
  (null, 'this_or_that', $${"a":"Soccer","b":"Basketball"}$$, $$soccer|basketball$$, 'ai'),
  (null, 'this_or_that', $${"a":"Camping trip","b":"Sleepover"}$$, $$camping trip|sleepover$$, 'ai'),
  (null, 'this_or_that', $${"a":"Puppies","b":"Kittens"}$$, $$puppies|kittens$$, 'ai'),
  (null, 'this_or_that', $${"a":"Pancakes","b":"Waffles"}$$, $$pancakes|waffles$$, 'ai'),
  (null, 'this_or_that', $${"a":"Go swimming","b":"Go hiking"}$$, $$go swimming|go hiking$$, 'ai'),
  (null, 'this_or_that', $${"a":"Board games","b":"Video games"}$$, $$board games|video games$$, 'ai'),
  (null, 'this_or_that', $${"a":"A treehouse","b":"A castle"}$$, $$a treehouse|a castle$$, 'ai'),
  (null, 'this_or_that', $${"a":"Ride a rocket","b":"Ride a submarine"}$$, $$ride a rocket|ride a submarine$$, 'ai'),
  (null, 'this_or_that', $${"a":"Talk to animals","b":"Breathe underwater"}$$, $$talk to animals|breathe underwater$$, 'ai'),
  (null, 'this_or_that', $${"a":"A pet dragon","b":"A pet robot"}$$, $$a pet dragon|a pet robot$$, 'ai'),
  (null, 'this_or_that', $${"a":"Pizza for breakfast","b":"Pancakes for dinner"}$$, $$pizza for breakfast|pancakes for dinner$$, 'ai'),
  (null, 'this_or_that', $${"a":"Be invisible","b":"Be super fast"}$$, $$be invisible|be super fast$$, 'ai'),
  (null, 'this_or_that', $${"a":"A big garden","b":"A big treehouse"}$$, $$a big garden|a big treehouse$$, 'ai'),
  (null, 'this_or_that', $${"a":"A telescope","b":"A microscope"}$$, $$a telescope|a microscope$$, 'ai'),
  (null, 'this_or_that', $${"a":"Explore a jungle","b":"Explore a desert"}$$, $$explore a jungle|explore a desert$$, 'ai'),
  (null, 'this_or_that', $${"a":"Be an astronaut","b":"Be a deep-sea diver"}$$, $$be an astronaut|be a deep-sea diver$$, 'ai'),
  (null, 'this_or_that', $${"a":"Make music","b":"Make art"}$$, $$make music|make art$$, 'ai'),
  (null, 'this_or_that', $${"a":"A roller coaster","b":"A water slide"}$$, $$a roller coaster|a water slide$$, 'ai'),
  (null, 'this_or_that', $${"a":"Visit a museum","b":"Visit a zoo"}$$, $$visit a museum|visit a zoo$$, 'ai'),
  (null, 'this_or_that', $${"a":"Tacos","b":"Burgers"}$$, $$tacos|burgers$$, 'ai'),
  (null, 'this_or_that', $${"a":"Snow day","b":"Beach day"}$$, $$snow day|beach day$$, 'ai'),
  (null, 'this_or_that', $${"a":"Dragons","b":"Unicorns"}$$, $$dragons|unicorns$$, 'ai'),
  (null, 'this_or_that', $${"a":"Tell jokes","b":"Tell stories"}$$, $$tell jokes|tell stories$$, 'ai')
on conflict do nothing;

-- ── Category (Beat the Letter / Starts-With prompts) ─────────────────────
insert into public.content_items (space_id, kind, payload, fingerprint, source) values
  (null, 'category', $${"label":"something round"}$$, $$something round$$, 'ai'),
  (null, 'category', $${"label":"an animal that swims"}$$, $$an animal that swims$$, 'ai'),
  (null, 'category', $${"label":"a fruit"}$$, $$a fruit$$, 'ai'),
  (null, 'category', $${"label":"something cold"}$$, $$something cold$$, 'ai'),
  (null, 'category', $${"label":"a thing with wheels"}$$, $$a thing with wheels$$, 'ai'),
  (null, 'category', $${"label":"something in the sky"}$$, $$something in the sky$$, 'ai'),
  (null, 'category', $${"label":"a musical instrument"}$$, $$a musical instrument$$, 'ai'),
  (null, 'category', $${"label":"something you read"}$$, $$something you read$$, 'ai'),
  (null, 'category', $${"label":"a vegetable"}$$, $$a vegetable$$, 'ai'),
  (null, 'category', $${"label":"something that makes noise"}$$, $$something that makes noise$$, 'ai'),
  (null, 'category', $${"label":"a place you can visit"}$$, $$a place you can visit$$, 'ai'),
  (null, 'category', $${"label":"something soft"}$$, $$something soft$$, 'ai'),
  (null, 'category', $${"label":"a kind of weather"}$$, $$a kind of weather$$, 'ai'),
  (null, 'category', $${"label":"something that grows"}$$, $$something that grows$$, 'ai'),
  (null, 'category', $${"label":"a tool"}$$, $$a tool$$, 'ai'),
  (null, 'category', $${"label":"something at the beach"}$$, $$something at the beach$$, 'ai'),
  (null, 'category', $${"label":"a dinosaur"}$$, $$a dinosaur$$, 'ai'),
  (null, 'category', $${"label":"something that floats"}$$, $$something that floats$$, 'ai'),
  (null, 'category', $${"label":"a thing in your kitchen"}$$, $$a thing in your kitchen$$, 'ai'),
  (null, 'category', $${"label":"an animal with a tail"}$$, $$an animal with a tail$$, 'ai')
on conflict do nothing;

-- ── Line (a neutral sentence to perform in the "As If" game) ─────────────
insert into public.content_items (space_id, kind, payload, fingerprint, source) values
  (null, 'line', $${"text":"Look what I found!"}$$, $$look what i found!$$, 'ai'),
  (null, 'line', $${"text":"We are going to be late."}$$, $$we are going to be late.$$, 'ai'),
  (null, 'line', $${"text":"Did you hear that?"}$$, $$did you hear that?$$, 'ai'),
  (null, 'line', $${"text":"I have a great idea."}$$, $$i have a great idea.$$, 'ai'),
  (null, 'line', $${"text":"This is the best day ever."}$$, $$this is the best day ever.$$, 'ai'),
  (null, 'line', $${"text":"Where did everybody go?"}$$, $$where did everybody go?$$, 'ai'),
  (null, 'line', $${"text":"I think we are lost."}$$, $$i think we are lost.$$, 'ai'),
  (null, 'line', $${"text":"Can you keep a secret?"}$$, $$can you keep a secret?$$, 'ai'),
  (null, 'line', $${"text":"It was right here a minute ago."}$$, $$it was right here a minute ago.$$, 'ai'),
  (null, 'line', $${"text":"Welcome to my show!"}$$, $$welcome to my show!$$, 'ai'),
  (null, 'line', $${"text":"Watch this!"}$$, $$watch this!$$, 'ai'),
  (null, 'line', $${"text":"That is not what I expected."}$$, $$that is not what i expected.$$, 'ai'),
  (null, 'line', $${"text":"Follow me, everyone."}$$, $$follow me, everyone.$$, 'ai'),
  (null, 'line', $${"text":"We did it together."}$$, $$we did it together.$$, 'ai'),
  (null, 'line', $${"text":"Something is different today."}$$, $$something is different today.$$, 'ai'),
  (null, 'line', $${"text":"I almost forgot!"}$$, $$i almost forgot!$$, 'ai')
on conflict do nothing;

-- ── As-If (an emotion / character / situation to perform a line in) ──────
insert into public.content_items (space_id, kind, payload, fingerprint, source) values
  (null, 'as_if', $${"text":"you just woke up"}$$, $$you just woke up$$, 'ai'),
  (null, 'as_if', $${"text":"you are a busy bee"}$$, $$you are a busy bee$$, 'ai'),
  (null, 'as_if', $${"text":"you are a melting snowman"}$$, $$you are a melting snowman$$, 'ai'),
  (null, 'as_if', $${"text":"you just found a treasure"}$$, $$you just found a treasure$$, 'ai'),
  (null, 'as_if', $${"text":"you are a brave knight"}$$, $$you are a brave knight$$, 'ai'),
  (null, 'as_if', $${"text":"you are a sleepy puppy"}$$, $$you are a sleepy puppy$$, 'ai'),
  (null, 'as_if', $${"text":"you are a famous chef"}$$, $$you are a famous chef$$, 'ai'),
  (null, 'as_if', $${"text":"you are an astronaut on the moon"}$$, $$you are an astronaut on the moon$$, 'ai'),
  (null, 'as_if', $${"text":"you are a tiny ant"}$$, $$you are a tiny ant$$, 'ai'),
  (null, 'as_if', $${"text":"you are a friendly dinosaur"}$$, $$you are a friendly dinosaur$$, 'ai'),
  (null, 'as_if', $${"text":"you are a gentle giant"}$$, $$you are a gentle giant$$, 'ai'),
  (null, 'as_if', $${"text":"you are a race car driver"}$$, $$you are a race car driver$$, 'ai'),
  (null, 'as_if', $${"text":"you are a magician"}$$, $$you are a magician$$, 'ai'),
  (null, 'as_if', $${"text":"you are a penguin on the ice"}$$, $$you are a penguin on the ice$$, 'ai'),
  (null, 'as_if', $${"text":"you are a wise old owl"}$$, $$you are a wise old owl$$, 'ai'),
  (null, 'as_if', $${"text":"you are a bouncy kangaroo"}$$, $$you are a bouncy kangaroo$$, 'ai'),
  (null, 'as_if', $${"text":"you are a superhero landing"}$$, $$you are a superhero landing$$, 'ai'),
  (null, 'as_if', $${"text":"you just made a big discovery"}$$, $$you just made a big discovery$$, 'ai')
on conflict do nothing;

-- ── Riddle (answer-first; fingerprint is the answer). New answers, no
--    overlap with the curated floor's set. ────────────────────────────────
insert into public.content_items (space_id, kind, payload, fingerprint, source) values
  (null, 'riddle', $${"prompt":"What has cities but no houses, forests but no trees, and rivers but no water?","answer":"A map"}$$, $$a map$$, 'ai'),
  (null, 'riddle', $${"prompt":"I follow you everywhere in the sunshine but hide when it is dark. What am I?","answer":"A shadow"}$$, $$a shadow$$, 'ai'),
  (null, 'riddle', $${"prompt":"What runs all day but never gets tired, and has a bed but never sleeps?","answer":"A river"}$$, $$a river$$, 'ai'),
  (null, 'riddle', $${"prompt":"What has a spine and lots of pages but never reads a word?","answer":"A book"}$$, $$a book$$, 'ai'),
  (null, 'riddle', $${"prompt":"What goes up and down but never moves an inch?","answer":"A staircase"}$$, $$a staircase$$, 'ai'),
  (null, 'riddle', $${"prompt":"What can travel all around the world while staying in one corner?","answer":"A stamp"}$$, $$a stamp$$, 'ai'),
  (null, 'riddle', $${"prompt":"What has keys but opens no locks, and space but no room?","answer":"A keyboard"}$$, $$a keyboard$$, 'ai'),
  (null, 'riddle', $${"prompt":"What gets bigger the more you take away from it?","answer":"A hole"}$$, $$a hole$$, 'ai'),
  (null, 'riddle', $${"prompt":"What answers back when you call but never says a new word?","answer":"An echo"}$$, $$an echo$$, 'ai'),
  (null, 'riddle', $${"prompt":"What flies without wings and floats without a boat?","answer":"A cloud"}$$, $$a cloud$$, 'ai'),
  (null, 'riddle', $${"prompt":"What has roots nobody sees and stands taller than the trees?","answer":"A mountain"}$$, $$a mountain$$, 'ai'),
  (null, 'riddle', $${"prompt":"What kind of band never plays any music?","answer":"A rubber band"}$$, $$a rubber band$$, 'ai'),
  (null, 'riddle', $${"prompt":"What is so fragile that just saying its name breaks it?","answer":"Silence"}$$, $$silence$$, 'ai'),
  (null, 'riddle', $${"prompt":"What comes down but never goes back up?","answer":"Rain"}$$, $$rain$$, 'ai'),
  (null, 'riddle', $${"prompt":"What has a ring but no finger?","answer":"A telephone"}$$, $$a telephone$$, 'ai'),
  (null, 'riddle', $${"prompt":"The more you have of it, the less you see. What is it?","answer":"Darkness"}$$, $$darkness$$, 'ai'),
  (null, 'riddle', $${"prompt":"What is always in front of you but can never be seen?","answer":"The future"}$$, $$the future$$, 'ai'),
  (null, 'riddle', $${"prompt":"What has a bark but no bite, and leaves but is not a door?","answer":"A tree"}$$, $$a tree$$, 'ai'),
  (null, 'riddle', $${"prompt":"What can fill a whole room but takes up no space at all?","answer":"Light"}$$, $$light$$, 'ai'),
  (null, 'riddle', $${"prompt":"I am light as a feather, yet the strongest person cannot hold me for very long. What am I?","answer":"Your breath"}$$, $$your breath$$, 'ai'),
  (null, 'riddle', $${"prompt":"What goes around the playground but never moves from its spot?","answer":"A fence"}$$, $$a fence$$, 'ai'),
  (null, 'riddle', $${"prompt":"What has four wheels and carries everyone but is not a car?","answer":"A bus"}$$, $$a bus$$, 'ai'),
  (null, 'riddle', $${"prompt":"What can you catch with your eyes but never with your hands?","answer":"Someone looking at you"}$$, $$someone looking at you$$, 'ai'),
  (null, 'riddle', $${"prompt":"What has a tail and a head but no body at all?","answer":"A coin"}$$, $$a coin$$, 'ai')
on conflict do nothing;

-- ── Fact-or-Fib (statement + isTrue boolean + the real fact for Reveal).
--    Every statement is factually accurate as marked. ──────────────────────
insert into public.content_items (space_id, kind, payload, fingerprint, source) values
  (null, 'fact_or_fib', $${"statement":"The Sun is a star.","isTrue":true,"note":"True — it is our closest star."}$$, $$the sun is a star.$$, 'ai'),
  (null, 'fact_or_fib', $${"statement":"Penguins can fly.","isTrue":false,"note":"Fib — penguins can't fly, but they are excellent swimmers."}$$, $$penguins can fly.$$, 'ai'),
  (null, 'fact_or_fib', $${"statement":"A baby kangaroo is called a joey.","isTrue":true,"note":"True — and it rides in its mother's pouch."}$$, $$a baby kangaroo is called a joey.$$, 'ai'),
  (null, 'fact_or_fib', $${"statement":"An octopus has eight arms.","isTrue":true,"note":"True — eight arms, and three hearts too!"}$$, $$an octopus has eight arms.$$, 'ai'),
  (null, 'fact_or_fib', $${"statement":"Sharks are mammals.","isTrue":false,"note":"Fib — sharks are fish."}$$, $$sharks are mammals.$$, 'ai'),
  (null, 'fact_or_fib', $${"statement":"The blue whale is the largest animal that has ever lived.","isTrue":true,"note":"True — bigger than any dinosaur."}$$, $$the blue whale is the largest animal that has ever lived.$$, 'ai'),
  (null, 'fact_or_fib', $${"statement":"Spiders have six legs.","isTrue":false,"note":"Fib — spiders have eight legs (insects have six)."}$$, $$spiders have six legs.$$, 'ai'),
  (null, 'fact_or_fib', $${"statement":"The Moon makes its own light.","isTrue":false,"note":"Fib — the Moon reflects light from the Sun."}$$, $$the moon makes its own light.$$, 'ai'),
  (null, 'fact_or_fib', $${"statement":"Some frogs can freeze in winter and thaw out alive in spring.","isTrue":true,"note":"True — wood frogs really do this."}$$, $$some frogs can freeze in winter and thaw out alive in spring.$$, 'ai'),
  (null, 'fact_or_fib', $${"statement":"A group of lions is called a pride.","isTrue":true,"note":"True — a pride of lions."}$$, $$a group of lions is called a pride.$$, 'ai'),
  (null, 'fact_or_fib', $${"statement":"Bats are blind.","isTrue":false,"note":"Fib — bats can see, and many also use sound to fly in the dark."}$$, $$bats are blind.$$, 'ai'),
  (null, 'fact_or_fib', $${"statement":"Tomatoes are a fruit.","isTrue":true,"note":"True — they grow from a flower and have seeds."}$$, $$tomatoes are a fruit.$$, 'ai'),
  (null, 'fact_or_fib', $${"statement":"A rainbow has seven main colors.","isTrue":true,"note":"True — red, orange, yellow, green, blue, indigo, violet."}$$, $$a rainbow has seven main colors.$$, 'ai'),
  (null, 'fact_or_fib', $${"statement":"Penguins live at the North Pole with polar bears.","isTrue":false,"note":"Fib — penguins live in the south; polar bears in the far north."}$$, $$penguins live at the north pole with polar bears.$$, 'ai'),
  (null, 'fact_or_fib', $${"statement":"Bamboo is one of the fastest-growing plants on Earth.","isTrue":true,"note":"True — some bamboo grows almost a meter in a day."}$$, $$bamboo is one of the fastest-growing plants on earth.$$, 'ai'),
  (null, 'fact_or_fib', $${"statement":"A starfish can grow back an arm it loses.","isTrue":true,"note":"True — many sea stars regrow lost arms."}$$, $$a starfish can grow back an arm it loses.$$, 'ai'),
  (null, 'fact_or_fib', $${"statement":"Water is made of hydrogen and oxygen.","isTrue":true,"note":"True — two hydrogen and one oxygen (H2O)."}$$, $$water is made of hydrogen and oxygen.$$, 'ai'),
  (null, 'fact_or_fib', $${"statement":"An adult human has 206 bones.","isTrue":true,"note":"True — babies have more, and some fuse as we grow."}$$, $$an adult human has 206 bones.$$, 'ai'),
  (null, 'fact_or_fib', $${"statement":"Goldfish forget everything after three seconds.","isTrue":false,"note":"Fib — goldfish can remember things for months."}$$, $$goldfish forget everything after three seconds.$$, 'ai'),
  (null, 'fact_or_fib', $${"statement":"Honey is made by bees.","isTrue":true,"note":"True — from the nectar of flowers."}$$, $$honey is made by bees.$$, 'ai'),
  (null, 'fact_or_fib', $${"statement":"The Great Barrier Reef is a living thing made by tiny coral animals.","isTrue":true,"note":"True — built by billions of tiny corals."}$$, $$the great barrier reef is a living thing made by tiny coral animals.$$, 'ai'),
  (null, 'fact_or_fib', $${"statement":"You can see the Great Wall of China from the Moon with your own eyes.","isTrue":false,"note":"Fib — it is far too narrow to see from that far away."}$$, $$you can see the great wall of china from the moon with your own eyes.$$, 'ai'),
  (null, 'fact_or_fib', $${"statement":"A cheetah is the fastest land animal.","isTrue":true,"note":"True — it can sprint faster than a car on a city street."}$$, $$a cheetah is the fastest land animal.$$, 'ai'),
  (null, 'fact_or_fib', $${"statement":"Plants make their food using sunlight.","isTrue":true,"note":"True — it is called photosynthesis."}$$, $$plants make their food using sunlight.$$, 'ai')
on conflict do nothing;

-- ── Story starters (an opener the room builds on aloud) ──────────────────
insert into public.content_items (space_id, kind, payload, fingerprint, source) values
  (null, 'story_starter', $${"text":"On the way to school, the bus took a turn no one had ever seen before."}$$, $$on the way to school, the bus took a turn no one had ever seen before.$$, 'ai'),
  (null, 'story_starter', $${"text":"A box arrived with your name on it and tiny holes poked in the top."}$$, $$a box arrived with your name on it and tiny holes poked in the top.$$, 'ai'),
  (null, 'story_starter', $${"text":"The library had a book that wrote itself as you read it."}$$, $$the library had a book that wrote itself as you read it.$$, 'ai'),
  (null, 'story_starter', $${"text":"Every clock in town stopped at exactly the same minute."}$$, $$every clock in town stopped at exactly the same minute.$$, 'ai'),
  (null, 'story_starter', $${"text":"A small, friendly dragon was asleep in the cafeteria."}$$, $$a small, friendly dragon was asleep in the cafeteria.$$, 'ai'),
  (null, 'story_starter', $${"text":"You found a key that fit no door you had ever seen."}$$, $$you found a key that fit no door you had ever seen.$$, 'ai'),
  (null, 'story_starter', $${"text":"The class plant grew overnight, all the way to the ceiling."}$$, $$the class plant grew overnight, all the way to the ceiling.$$, 'ai'),
  (null, 'story_starter', $${"text":"A map fell out of an old jacket, marked with a bright red X."}$$, $$a map fell out of an old jacket, marked with a bright red x.$$, 'ai'),
  (null, 'story_starter', $${"text":"The new student could understand what the school cat was saying."}$$, $$the new student could understand what the school cat was saying.$$, 'ai'),
  (null, 'story_starter', $${"text":"A door appeared in the playground that wasn't there yesterday."}$$, $$a door appeared in the playground that wasn't there yesterday.$$, 'ai'),
  (null, 'story_starter', $${"text":"Footprints made of light led all the way across the gym floor."}$$, $$footprints made of light led all the way across the gym floor.$$, 'ai'),
  (null, 'story_starter', $${"text":"A snowman knocked politely on the classroom window."}$$, $$a snowman knocked politely on the classroom window.$$, 'ai'),
  (null, 'story_starter', $${"text":"The school bell rang out a song instead of a ring."}$$, $$the school bell rang out a song instead of a ring.$$, 'ai'),
  (null, 'story_starter', $${"text":"A paper boat floated up the hallway, sailing against the wind."}$$, $$a paper boat floated up the hallway, sailing against the wind.$$, 'ai'),
  (null, 'story_starter', $${"text":"One morning, everyone's drawings started to move on the page."}$$, $$one morning, everyone's drawings started to move on the page.$$, 'ai'),
  (null, 'story_starter', $${"text":"A tiny rocket the size of a pencil landed on the windowsill."}$$, $$a tiny rocket the size of a pencil landed on the windowsill.$$, 'ai')
on conflict do nothing;

-- ── Story twists ("Plot twist!" cards to drop into a story in progress) ──
insert into public.content_items (space_id, kind, payload, fingerprint, source) values
  (null, 'story_twist', $${"text":"Suddenly, it starts to rain upside down."}$$, $$suddenly, it starts to rain upside down.$$, 'ai'),
  (null, 'story_twist', $${"text":"A tiny voice whispers, 'You're getting warmer.'"}$$, $$a tiny voice whispers, 'you're getting warmer.'$$, 'ai'),
  (null, 'story_twist', $${"text":"The lights flicker, and everything turns a different color."}$$, $$the lights flicker, and everything turns a different color.$$, 'ai'),
  (null, 'story_twist', $${"text":"A door you've never seen swings wide open."}$$, $$a door you've never seen swings wide open.$$, 'ai'),
  (null, 'story_twist', $${"text":"It turns out the clue was written backward all along."}$$, $$it turns out the clue was written backward all along.$$, 'ai'),
  (null, 'story_twist', $${"text":"Your best friend has been keeping a wonderful secret."}$$, $$your best friend has been keeping a wonderful secret.$$, 'ai'),
  (null, 'story_twist', $${"text":"The smallest one in the group saves the day."}$$, $$the smallest one in the group saves the day.$$, 'ai'),
  (null, 'story_twist', $${"text":"Time skips forward one whole hour in a single blink."}$$, $$time skips forward one whole hour in a single blink.$$, 'ai'),
  (null, 'story_twist', $${"text":"A friendly stranger somehow knows your name."}$$, $$a friendly stranger somehow knows your name.$$, 'ai'),
  (null, 'story_twist', $${"text":"The map was the treasure the whole time."}$$, $$the map was the treasure the whole time.$$, 'ai'),
  (null, 'story_twist', $${"text":"Everything in the room starts to float."}$$, $$everything in the room starts to float.$$, 'ai'),
  (null, 'story_twist', $${"text":"A trapdoor opens right under your feet."}$$, $$a trapdoor opens right under your feet.$$, 'ai')
on conflict do nothing;

-- ── Rhyme words (a word for the room to rhyme with) ──────────────────────
insert into public.content_items (space_id, kind, payload, fingerprint, source) values
  (null, 'rhyme_word', $${"word":"fox"}$$, $$fox$$, 'ai'),
  (null, 'rhyme_word', $${"word":"moon"}$$, $$moon$$, 'ai'),
  (null, 'rhyme_word', $${"word":"bug"}$$, $$bug$$, 'ai'),
  (null, 'rhyme_word', $${"word":"rain"}$$, $$rain$$, 'ai'),
  (null, 'rhyme_word', $${"word":"fish"}$$, $$fish$$, 'ai'),
  (null, 'rhyme_word', $${"word":"goat"}$$, $$goat$$, 'ai'),
  (null, 'rhyme_word', $${"word":"duck"}$$, $$duck$$, 'ai'),
  (null, 'rhyme_word', $${"word":"rose"}$$, $$rose$$, 'ai'),
  (null, 'rhyme_word', $${"word":"bell"}$$, $$bell$$, 'ai'),
  (null, 'rhyme_word', $${"word":"frog"}$$, $$frog$$, 'ai'),
  (null, 'rhyme_word', $${"word":"hat"}$$, $$hat$$, 'ai'),
  (null, 'rhyme_word', $${"word":"shoe"}$$, $$shoe$$, 'ai'),
  (null, 'rhyme_word', $${"word":"pig"}$$, $$pig$$, 'ai'),
  (null, 'rhyme_word', $${"word":"nest"}$$, $$nest$$, 'ai'),
  (null, 'rhyme_word', $${"word":"boat"}$$, $$boat$$, 'ai'),
  (null, 'rhyme_word', $${"word":"kite"}$$, $$kite$$, 'ai'),
  (null, 'rhyme_word', $${"word":"bear"}$$, $$bear$$, 'ai'),
  (null, 'rhyme_word', $${"word":"rock"}$$, $$rock$$, 'ai'),
  (null, 'rhyme_word', $${"word":"drum"}$$, $$drum$$, 'ai'),
  (null, 'rhyme_word', $${"word":"mouse"}$$, $$mouse$$, 'ai'),
  (null, 'rhyme_word', $${"word":"train"}$$, $$train$$, 'ai'),
  (null, 'rhyme_word', $${"word":"sock"}$$, $$sock$$, 'ai'),
  (null, 'rhyme_word', $${"word":"wing"}$$, $$wing$$, 'ai'),
  (null, 'rhyme_word', $${"word":"pail"}$$, $$pail$$, 'ai')
on conflict do nothing;

-- ── Charades (word to act out + the category the room sees) ───────────────
insert into public.content_items (space_id, kind, payload, fingerprint, source) values
  (null, 'charades', $${"word":"A cat","category":"Animal"}$$, $$a cat$$, 'ai'),
  (null, 'charades', $${"word":"A frog","category":"Animal"}$$, $$a frog$$, 'ai'),
  (null, 'charades', $${"word":"A bird","category":"Animal"}$$, $$a bird$$, 'ai'),
  (null, 'charades', $${"word":"A bee","category":"Animal"}$$, $$a bee$$, 'ai'),
  (null, 'charades', $${"word":"A horse","category":"Animal"}$$, $$a horse$$, 'ai'),
  (null, 'charades', $${"word":"A crab","category":"Animal"}$$, $$a crab$$, 'ai'),
  (null, 'charades', $${"word":"An owl","category":"Animal"}$$, $$an owl$$, 'ai'),
  (null, 'charades', $${"word":"A rabbit","category":"Animal"}$$, $$a rabbit$$, 'ai'),
  (null, 'charades', $${"word":"Brushing your hair","category":"Action"}$$, $$brushing your hair$$, 'ai'),
  (null, 'charades', $${"word":"Washing the dishes","category":"Action"}$$, $$washing the dishes$$, 'ai'),
  (null, 'charades', $${"word":"Painting a wall","category":"Action"}$$, $$painting a wall$$, 'ai'),
  (null, 'charades', $${"word":"Riding a bike","category":"Action"}$$, $$riding a bike$$, 'ai'),
  (null, 'charades', $${"word":"Jumping rope","category":"Action"}$$, $$jumping rope$$, 'ai'),
  (null, 'charades', $${"word":"Blowing bubbles","category":"Action"}$$, $$blowing bubbles$$, 'ai'),
  (null, 'charades', $${"word":"Reading a book","category":"Action"}$$, $$reading a book$$, 'ai'),
  (null, 'charades', $${"word":"Watering the plants","category":"Action"}$$, $$watering the plants$$, 'ai'),
  (null, 'charades', $${"word":"A king","category":"Character"}$$, $$a king$$, 'ai'),
  (null, 'charades', $${"word":"A clown","category":"Character"}$$, $$a clown$$, 'ai'),
  (null, 'charades', $${"word":"A friendly ghost","category":"Character"}$$, $$a friendly ghost$$, 'ai'),
  (null, 'charades', $${"word":"A robot dancing","category":"Character"}$$, $$a robot dancing$$, 'ai'),
  (null, 'charades', $${"word":"A fairy","category":"Character"}$$, $$a fairy$$, 'ai'),
  (null, 'charades', $${"word":"A detective","category":"Character"}$$, $$a detective$$, 'ai'),
  (null, 'charades', $${"word":"Swimming","category":"Sport"}$$, $$swimming$$, 'ai'),
  (null, 'charades', $${"word":"Playing tennis","category":"Sport"}$$, $$playing tennis$$, 'ai'),
  (null, 'charades', $${"word":"Ice skating","category":"Sport"}$$, $$ice skating$$, 'ai'),
  (null, 'charades', $${"word":"A doctor","category":"Job"}$$, $$a doctor$$, 'ai'),
  (null, 'charades', $${"word":"A teacher","category":"Job"}$$, $$a teacher$$, 'ai'),
  (null, 'charades', $${"word":"An astronaut","category":"Job"}$$, $$an astronaut$$, 'ai')
on conflict do nothing;
