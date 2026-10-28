# Oath of the Frost-Crown Campaign

The campaign context describes how playable Levels, combat outcomes, and Stories form the player's ordered journey through the game.

## Current Four-Symbol Content

The active narrative overhaul is 《逆岁：四契》. The player is 拾契人砚, and
the four campaign bosses are 白虎、朱雀、玄武、青龙. Their masks are the
白虎面具、朱雀面具、玄武面具 and 青龙面具.

Legacy implementation names may remain in scene paths, node names, scripts and
mechanics sections so the existing campaign contracts keep working. In the
current content pass, Level01 presents 白虎, Level02 presents 朱雀, Level03
presents 玄武, and Level04 presents 青龙. These presentation mappings supersede
the old character and boss names in player-facing text, not the underlying
technical contracts.

## Language

**Campaign Prologue Page**:
The single-page narrative preface with narrative-page music presented after the Player starts the campaign and before the Input Guide. It is distinct from the later playable Level 00 narrative sequence.
_Avoid_: Level 00, Opening Story, prologue Level

**Input Guide**:
The campaign instruction page presented after the Campaign Prologue Page. Continuing from it begins Level 01 and its Opening Story.
_Avoid_: Campaign Prologue Page, Opening Story

**Continuation Input**:
A new keyboard-key, mouse-button, gamepad-button, or touchscreen press received after the Campaign Prologue Page or Campaign Epilogue Page becomes active. Releases, key-repeat echoes, pointer motion, and analog-axis motion are not Continuation Inputs, and the input that opens a page cannot also continue past it.
_Avoid_: Any input event, held input, opening input

**Level Completion**:
The successful combat outcome of a Level. It begins that Level's Victory Story when one exists; it does not itself advance to the next Level.
_Avoid_: Level ending, campaign completion

**Victory Story**:
The closing narrative phase that follows Level Completion. Only after the Victory Story finishes may the campaign advance to another Level or enter its final terminal presentation.
_Avoid_: Ending, result screen

**Opening Story**:
The introductory narrative phase of a newly active Level. In Level 01 through Level 04, it begins after that Level's Act Announcement and together with its campaign music; gameplay remains unavailable until the Story finishes, after which that same Level enters Level Initialization.
_Avoid_: Victory Story, Level Initialization

**Act Announcement**:
The silent title-card narrative beat immediately preceding the Opening Story of Level 01 through Level 04. It identifies that Level's numbered Act and title, and remains distinct from the Opening Story itself.
_Avoid_: Opening Story, Campaign Prologue Page, Level title

**Valdemar Pre-Awakening Story**:
The one-time Level 04 narrative phase that begins when the Player first enters Valdemar's throne-room boundary during the initial story-bearing attempt. It pauses gameplay before Valdemar Awakening begins; finishing it immediately begins that awakening, while a retry omits this Story and begins the awakening directly at the boundary.
_Avoid_: Opening Story, Victory Story, Valdemar Awakening, replayed retry Story

**Valdemar Post-Defeat Story**:
The Level 04 Victory Story that begins only after Valdemar's complete death motion reaches its retained Dying presentation and constitutes Level 04 Completion.
_Avoid_: Health-depletion Story, interrupted death motion, ordinary post-combat dialogue

**Level Advancement**:
The replacement of the completed Level with a newly initialized next Level after its Victory Story finishes.
_Avoid_: Level Completion, scene jump

**Level Initialization**:
The playable starting state of a newly active Level: full Player health, visible HUD, available controls, the Player Camera active, no result interface, and an unpaused campaign. A Level without an Opening Story enters this state immediately.
_Avoid_: Scene instantiation, Level Advancement

**Campaign Autosave**:
The single versioned JSON save at `user://campaign_autosave.json`. It stores the active campaign id, checkpoint id, unlocked mask ids, and equipped mask id using plain data rather than scene references. Writes use a temporary file and retain the previous valid save as a `.bak` fallback.
_Avoid_: Scene serialization, manual save slot, settings file

**Campaign Checkpoint**:
Either the Level Start Checkpoint written after a Level's Opening Story finishes, or the Boss Checkpoint written once after the Player crosses the Boss Door into the combat area. Continue and defeat retry rebuild the saved Level from this data; the Boss Checkpoint restores the Player beyond the locked Boss Door.
_Avoid_: Arbitrary position save, encounter-state serialization, debug checkpoint

**Pause Menu**:
The Esc-driven campaign overlay available only during active gameplay. It pauses the SceneTree and provides resume, checkpoint retry, settings, return-to-title, and quit actions; it is unavailable during Stories, result interfaces, title pages, campaign pages, and act announcements.
_Avoid_: Story pause, automatic result pause, debug menu

**Game Settings**:
The independently persisted player preferences at `user://settings.json`, containing Master volume and fullscreen mode. Settings apply immediately and are loaded before the campaign title is used.
_Avoid_: Campaign save data, per-Level settings, editor settings

### Combat

**Player Attack Cooldown**:
The fixed eight-tenths-second gameplay interval shared by every Player form, beginning when the Player accepts an attack input and starts that attack; every new Player instance begins with no active interval, while a Story or another campaign pause suspends an active interval until gameplay resumes. An attack press received during the interval records one Pending Player Attack, and further presses during the same interval merge into that single pending attack rather than accumulating additional attacks; subsequent Player Hurt neither pauses nor resets the interval, and Thunder released by later Player forms remains part of the same attack rather than having an independent cooldown.
_Avoid_: Attack animation duration, Player Hurt Immunity, Thunder cooldown

**Pending Player Attack**:
The single Player attack recorded by one or more new attack presses while Player Attack Cooldown or Player Hurt prevents an attack from beginning. At most one can exist regardless of how many such presses occur; releasing the control does not cancel it, while holding the control without a new press neither creates another pending attack nor causes automatic repeated attacks. It begins as soon as both the cooldown and Player Hurt have finished, and uses the Player's facing when it begins rather than the facing at the recorded input. An explicit Player control lock clears it and rejects new attack presses until control returns.
_Avoid_: Attack queue, repeated attacks, held attack, recorded attack direction, post-cinematic attack

**Player Hurt Immunity**:
The one-and-a-half-second protection that follows accepted non-lethal damage to the Player and rejects otherwise applicable damage, outlasting the nine-tenths-second hurt presentation. It is distinct from explicit damage immunity granted for a cinematic or terminal outcome.
_Avoid_: Invincibility, damage immunity, invincibility frames

**Player Dodge**:
The universal Shift-triggered horizontal dash available while Player controls are enabled and Dodge Cooldown is ready. It lasts 0.15 seconds at 940 pixels per second, plays a dedicated eight-frame dodge sequence, and moves in the current left/right input direction or the Player's facing when no horizontal input exists. It provides movement only: it does not grant invincibility or contact-damage immunity, and accepted damage interrupts the dodge. It may cancel an Attack and creates a cyan afterimage trail.
_Avoid_: Air dash, mask skill, invincibility frame, attack-independent cooldown

**Dodge Cooldown**:
The 0.3-second interval beginning when Player Dodge starts. It continues through other Player states but is suspended while the SceneTree is paused for a Story or the Pause Menu.
_Avoid_: Attack Cooldown, mask cooldown, Player Hurt Immunity

**Persistent Damage Contact**:
The Player's uninterrupted physical contact with a damage source that remains able to deal damage over time, such as a living Enemy's body or an active Black Water Field; separation, loss of the source's damage capability, explicit Player damage immunity, or a terminal outcome makes the contact invalid. If contact remains valid when Player Hurt Immunity ends, one contact immediately produces another complete accepted-damage response—including health loss, the hurt event and presentation, knockback, and renewed Player Hurt Immunity—without requiring contact re-entry; the contact need not be the source that started the immunity and remains applicable if it began or attempted damage during that immunity, while simultaneous contacts cannot produce additional accepted damage during the renewed immunity.
_Avoid_: Skill hit, repeated hit from one skill release, contact re-entry, originating damage source

**Black Water Field**:
The Level 04 field associated with Valdemar's Black Water Cast. It rests below the playable ground between casts and becomes hazardous through its cast motion whenever Valdemar requests it; while it overlaps the Player, uninterrupted contact deals one damage per accepted hit and follows Persistent Damage Contact rather than the once-per-release rule used by ordinary skill hits. Its accepted hits use the ordinary source-relative knockback and Player damage response without a Black Water-specific exception.
_Avoid_: One-hit skill, Valdemar contact damage, permanent terrain hazard

**Boss Stability**:
The rule that accepted damage never displaces a Boss, although it may still reduce health, grant hurt immunity, or cause a hurt presentation according to that Boss's current action. Every Boss retains its position instead of inheriting ordinary Enemy hurt knockback.
_Avoid_: Damage immunity, skill immunity, ordinary Enemy knockback

**Valdemar**:
The final Boss encountered in the Level 04 throne room. He has fifteen maximum health and remains in his Normal Form until the Valdemar Awakening turns him into Dark Mode.
_Avoid_: King, Elk King, generic species King

**Valdemar Awakening**:
The one-time transition that begins when the Valdemar Pre-Awakening Story finishes during the initial story-bearing Level 04 attempt, or immediately when the Player enters the throne-room boundary on a retry. The boundary extends eight hundred horizontal pixels from Valdemar regardless of height; he cannot pursue, perform active attacks, take damage, or progress his Black Water Cycle before this transition finishes, whose completion enters Dark Mode, enables his active combat behavior, and begins the first Black Water Cycle.
_Avoid_: Level initialization, Boss Door crossing, preloaded Dark Mode

**Valdemar Health Presentation**:
The Boss Health Bar representing Valdemar's fifteen health. It remains hidden throughout Normal Form and Valdemar Awakening, becomes visible when Dark Mode begins, reflects each accepted damage event, and disappears on Valdemar Defeat.
_Avoid_: Player HUD health, pre-awakening health bar, Normal Form damage

**Valdemar Hurt**:
The four-tenths-second non-lethal damage response that stops Valdemar's pursuit or sword-cooldown waiting without displacing him, presents his full hurt motion, and then resumes pursuit when hurt immunity finishes. Damage accepted during a Sword Gleam still reduces health and grants the same hurt-immunity interval without changing that attack's position, facing, or presentation, while damage attempted during a Black Water Cast is rejected by Valdemar Black Water Immunity.
_Avoid_: Boss knockback, cast interruption, Awakening damage

**Valdemar Contact Damage**:
The one damage dealt through physical contact with Valdemar in Normal Form, during Valdemar Awakening, or throughout Dark Mode, followed by the Player's ordinary knockback and hurt immunity. It is passive rather than an active attack and ends only on Valdemar Defeat.
_Avoid_: Sword Gleam, contact-safe form, repeated damage during Player hurt immunity

**Valdemar Sword Pursuit**:
Valdemar's unbounded Dark Mode movement at one hundred fifty pixels per second, independent of a Skill Detection Area. When his and the Player's vertical coordinates differ by fewer than ten pixels, he pursues the Player's body; otherwise, he locks the position that would align his currently facing Sword Gleam with the Player, turns before running there when necessary, and then turns back to present that Sword Gleam at the Player, while Sword Gleam readiness never changes either target or makes him reverse solely to create or preserve alignment.
_Avoid_: Enemy patrol, bounded chase, proximity-gated chase, physical floor contact

**Valdemar Facing-Coherent Movement**:
The rule that Valdemar always faces the direction of his horizontal movement. Before any pursuit movement whose direction differs from his facing, he turns to that direction first; he never slides or runs backward.
_Avoid_: Backpedaling, backward run, movement-facing mismatch

**Valdemar Sword Gleam**:
A half-second Dark Mode attack that is immediately available upon entering Dark Mode and begins whenever the ready Sword Gleam's horizontal center reaches or crosses the Player's horizontal coordinate through pursuit movement, or becomes exactly aligned when Valdemar turns back at a locked destination; changing facing anywhere else does not count as crossing or alignment. It pairs Valdemar's locked attack position and facing with the Guard Sword Gleam, deals one damage to a given target at most once, and starts an independent four-second cooldown that continues through pursuit, hurt, and Black Water Cast; non-lethal damage cannot interrupt a release, while Valdemar Defeat prevents any further damage from it.
_Avoid_: Guard Sword Gleam cooldown, Valdemar skill presentation, contact damage

**Valdemar Black Water Cycle**:
The repeating sixteen-second interval that begins when Valdemar enters Dark Mode. A completed interval makes one Black Water Cast due and takes priority over a Sword Gleam that has not started; it remains as one pending cast while an active Sword Gleam or hurt presentation finishes, and restarts only when that cast actually begins.
_Avoid_: Ten-second signal interval, immediate first request, Sword Gleam

**Valdemar Release Priority**:
A due Black Water Cast takes priority only before a Sword Gleam has entered its Enemy Release Warning. Once either release has begun its own warning, that warning and release finish before the other action may begin a separate warning.
_Avoid_: Warning interruption, combined release, concurrent release, shared warning

**Valdemar Black Water Cast**:
A stationary six-second skill presentation that begins facing the Player, locks Valdemar's position and facing, presents nine frames over its first three seconds, and deliberately holds its final frame for the remaining three. It requests exactly one Black Water Field cast when it begins, grants Valdemar Black Water Immunity, and prevents pursuit or Sword Gleam until it finishes; Valdemar Defeat clears any pending cast and stops all future Black Water Cycles, while defeat through incoming damage cannot occur during an active cast.
_Avoid_: Sword Gleam, interruptible cast, permanent Black Water hazard

**Valdemar Black Water Immunity**:
The explicit damage immunity lasting for the full Valdemar Black Water Cast. Every incoming damage attempt during this interval is rejected without changing health, beginning hurt immunity, or presenting Valdemar Hurt.
_Avoid_: Valdemar Hurt, cast interruption, Sword Gleam damage handling

**Valdemar Defeat**:
The Boss combat outcome reached when Valdemar's health is depleted. It disables his pursuit, attacks, Black Water Cycle, and combat collisions, hides his Health Bar, and preserves his position and facing through the complete dead motion into the retained Dying presentation; it remains distinct from the later Level 04 Completion.
_Avoid_: Level 04 Completion, immediate cleanup

**Level 04 Completion**:
The successful Level 04 outcome reached when Valdemar's complete death motion enters its retained Dying presentation and emits one `died` event. It immediately begins the Valdemar Post-Defeat Story rather than occurring when his health is first depleted.
_Avoid_: Valdemar Defeat, health depletion, interrupted death motion

**Level 04 Terminal Outcome Lock**:
The first confirmed health depletion between the Player and Valdemar irreversibly fixes Level 04's terminal outcome, including when both occur during the same physics frame. Valdemar Defeat first immediately hides the HUD, removes Player control, and grants terminal Player damage immunity so no lingering combat effect can replace the victory, while Player Defeat first prevents any later Valdemar Defeat from replacing the loss; Level 04 Completion still waits for Valdemar's complete death motion after a locked victory.
_Avoid_: Simultaneous terminal presentations, same-frame outcome replacement, delayed victory decision

**Level 04 Closing Tableau**:
The non-interactive combat composition retained through the Valdemar Post-Defeat Story, with Valdemar in his Dying presentation, the HUD hidden, and Player control unavailable. When that Story finishes, the campaign leaves this tableau for the Campaign Epilogue Page.
_Avoid_: Campaign Epilogue Page, result screen, restored gameplay

**Campaign Epilogue Page**:
The single-page narrative conclusion with narrative-page music presented after the Valdemar Post-Defeat Story and after Level 04 and its music have ended. Continuing from it enters the Producer Page.
_Avoid_: Valdemar Post-Defeat Story, Level 04 Closing Tableau, result screen

**Producer Page**:
The campaign's final presentation with narrative-page music entered from the Campaign Epilogue Page. It remains visible indefinitely and does not accept Continuation Input or initiate another campaign transition.
_Avoid_: Campaign Epilogue Page, title page, restart page

**Elk King**:
A Boss variant of the Elk with ten maximum health that retains the Elk's thunder and passive shield while adding an independently triggered earthquake ability.
_Avoid_: Generic multi-skill Enemy, unrelated Enemy species

**Skill Detection Area**:
The forward-facing region in which the Player's presence allows an Enemy to initiate its species skill whenever that skill is ready. Remaining inside continues to satisfy this condition, so an Enemy releases the skill again when its cooldown ends without requiring the Player to leave and re-enter.
_Avoid_: Aggro range, attack range

**Active Enemy Release**:
An Enemy-initiated attack or skill release that can actively harm the Player. Passive contact damage and passive defenses are not Active Enemy Releases.
_Avoid_: Enemy contact damage, passive shield response

**Enemy Release Warning**:
The seven-tenths-second stationary warning that precedes every Active Enemy Release, visibly marks the Enemy for the full interval, halts its active horizontal movement, and locks its current body presentation and release-facing until the mark disappears as the release begins; gravity remains applicable. Once begun, it commits the release despite Player departure and grants weapon immunity for its full duration, so incoming weapon contact cannot damage the Enemy or interrupt, cancel, reset, or retarget the warning, while passive Enemy contact damage remains applicable throughout.
_Avoid_: Active attack animation, frozen gravity, skill cooldown, passive-contact warning, contact-safe wind-up, vulnerable wind-up, release-time retargeting

**Enemy Release Cooldown**:
The release-specific interval that begins only when an Enemy Release Warning finishes and its committed Active Enemy Release actually starts.
_Avoid_: Warning duration, cooldown from warning onset

**Enemy Release Targeting**:
The existing species-specific target or strike-point selection preserved by an Enemy Release Warning: the warning locks the release side but does not become a ground-target indicator or redirect a release toward the Player. A random strike point is still selected when its release begins, within the original valid region on the locked side.
_Avoid_: Warning-mark target, Player tracking during warning, release-time side change

**Enemy Movement Stall**:
An active Enemy patrol, Wolf Dash, or Wolf King forward-skill movement frame in which movement was attempted but horizontal position changes by no more than one-tenth of a pixel. It alone reverses an environmentally blocked patrol or ends the moving skill; stationary states, obstacle proximity, collision contact by itself, and patrol-range boundaries are not Enemy Movement Stalls.
_Avoid_: Obstacle detection, collision stop, stationary frame

**Wolf Dash Warning**:
The stationary seven-tenths-second warning that begins when a ready Wolf detects the Player, locks the Wolf's facing, and commits one subsequent dash in that direction. It grants the same weapon immunity as the ensuing dash, so neither Player departure from the Skill Detection Area nor incoming weapon contact cancels the committed dash.
_Avoid_: Dash animation, cancellable range check, moving warning, vulnerable wind-up

**Wolf King Skill Warning**:
The stationary seven-tenths-second warning that begins when a ready Wolf King detects the Player, locks the Wolf King's facing and release side, and commits one combined skill release, with its warning mark visible for the full interval while its body holds the presentation from warning onset. The mark disappears when the warning finishes, after which the body enters its run presentation and forward movement and thunder begin together toward the locked side; neither Player movement or departure from the Skill Detection Area nor incoming weapon contact retargets, cancels, interrupts, or resets the warning, and weapon contact cannot damage the Wolf King during it.
_Avoid_: Movement-only warning, thunder-only warning, active skill release, vulnerable wind-up, continued body animation, cancellable range check, release-time retargeting

**Wolf King Skill Cooldown**:
The three-second interval beginning when a Wolf King Skill Warning finishes and its committed combined release starts. The Wolf King cannot begin another warning during this interval, while continued Player presence in the Skill Detection Area satisfies the release condition again when the interval has ended and the Wolf King is otherwise ready.
_Avoid_: Warning duration, cooldown from warning start, Player re-entry requirement

**Wolf Dash Cooldown**:
The five-second interval beginning when a Wolf Dash Warning finishes and its committed dash starts. The Wolf cannot begin another warning during this interval, while continued Player presence in the Skill Detection Area initiates a new warning as soon as the interval has ended and the Wolf is otherwise ready.
_Avoid_: Warning duration, cooldown from warning start, Player re-entry requirement

**Hurt Completion Before Skill**:
The rule that an Enemy completes its non-lethal hurt presentation and associated hurt immunity before starting a ready skill. If the Player remains in the Skill Detection Area, the Enemy begins casting as soon as the hurt state finishes.
_Avoid_: Skill-interrupted hurt, early hurt-immunity termination

**Guard**:
An Enemy with three maximum health that uses the standard Enemy patrol and Skill Detection Area behavior to release Sword Gleam.
_Avoid_: Player-controlled guard, stationary sentry

**Guard Sword Gleam**:
A Guard skill whose synchronized attack motion, sword effect, and damage region are always presented on the side the Guard is facing. Each release deals one damage to a given target at most once and starts a five-second cooldown; non-lethal damage to the Guard does not interrupt a release already in progress, while Guard Defeat prevents any further damage from that release.
_Avoid_: Guard contact damage, repeated damage from one release, hurt-interrupted Sword Gleam

**Elk Thunder Strike Point**:
A grounded location whose horizontal coordinate is randomly selected from an Elk's Skill Detection Area when its thunder skill begins.
_Avoid_: Elk position, Player position

**Elk Thunder Cast**:
A stationary Enemy skill during which an Elk pauses its patrol, releases thunder at its selected Elk Thunder Strike Point, and then resumes its prior behavior.
_Avoid_: Thunder pursuit, moving cast

**Elk King Active Skills**:
The Elk King's independently timed thunder barrage and earthquake. Either ready skill can begin while the Player remains in the Skill Detection Area, but only one may be active at a time. Earthquake is deferred whenever the thunder barrage is active, regardless of its readiness; leaving after a warning starts or taking non-lethal damage does not cancel the committed release, while the Elk Shield is passive and does not participate in these decisions.
_Avoid_: Fixed thunder-then-earthquake sequence, concurrent thunder and earthquake, Elk King Shield cast

**Elk King Release Warning**:
The Enemy Release Warning that precedes each individual Elk King release. Each thunder barrage and each earthquake uses its own complete warning; a warning, newly ready cooldown, or second release cannot interrupt the skill already in progress.
_Avoid_: Per-skill warning, overlapping warning, mid-window skill insertion, concurrent release

**Elk King Casting Window**:
The interval in which one Elk King active release is being presented. The Elk King remains stationary throughout that release and resumes patrol or idle behavior after it finishes; earthquake cannot begin during the thunder barrage.
_Avoid_: Concurrent casting, per-skill movement resume, shared skill duration

**Elk King Thunder Barrage**:
The first phase of the ordered sequence: for six seconds, every six-tenths of a second, three thunder beams are created in three separate horizontal thirds of the visible map. The three positions in each wave must be non-adjacent, while their exact positions are randomized.
_Avoid_: Single thunder strike, nearby beam cluster, off-screen random strike

**Elk King Earthquake Cast**:
An independently triggered Elk King skill with its own warning and cooldown. It cannot be released during the thunder barrage and waits for that barrage to end. It can begin only while the Player is present in the Skill Detection Area, then commits through a new full warning before dealing one damage to a given target at most once per cast.
_Avoid_: Passive earthquake, idle-animation earthquake, rear-facing earthquake

**Elk King Casting Presentation**:
The Elk King keeps its skill presentation active for the complete duration of the individual thunder barrage or earthquake release currently in progress.
_Avoid_: Returning to idle during the barrage, concurrent animation blending

**Elk King Independent Skill Hit**:
Each thunder beam and each earthquake contribute independently resolved damage events. They are separated in time and never form a simultaneous thunder-plus-earthquake hit.
_Avoid_: Concurrent thunder and earthquake hit, duplicate damage from one beam

**Elk King Thunder Cooldown**:
The ten-second interval that begins only after the complete six-second thunder barrage ends. Thunder cannot begin while another Elk King release is active or during this post-barrage cooldown.
_Avoid_: Concurrent skill restart

**Elk King Earthquake Cooldown**:
The five-second interval beginning when the earthquake starts. A ready earthquake still waits whenever the thunder barrage is active.
_Avoid_: Overlapping earthquake, earthquake during thunder

**Elk King Defeat**:
The Boss combat outcome reached as soon as the Elk King's health is depleted. Thunder and earthquake casts that started before defeat may finish their visual presentation but can no longer damage the Player; the defeated Elk King remains part of Level 03 until that Level session is disposed, and Elk King Defeat is distinct from Level Completion.
_Avoid_: Level Completion, skill cancellation, Elk King cleanup

**Elk King Death Staging**:
The non-interactive transition between Elk King Defeat and its death presentation: the HUD is hidden, the Elk King faces left, and the damage-immune Player retains terrain physics, landing if necessary before running at normal speed to a point with an actual horizontal separation of 470 pixels on its left. The Player Camera follows this movement; once precisely aligned, the Player faces the Elk King, leaves physical interaction, and is seamlessly replaced by the matching Aila shown in the death presentation.
_Avoid_: Player input, teleport, airborne handoff, scaled local offset, visible character swap

**Elk King Death Tableau**:
The terminal Level 03 presentation held on the final frame of the Elk King's death presentation, with the Player Camera holding the final composition and the HUD remaining hidden. Reaching it constitutes Level Completion and immediately begins the Level 03 Victory Story without an intervening transition or result interface; the tableau remains while that Story plays, with the Player hidden, unavailable, and absent from physical interaction, until Level Advancement disposes the whole Level 03 session.
_Avoid_: Automatic Level disposal, restored Player control

**Level 03 Terminal Outcome Lock**:
The first confirmed health depletion between the Player and the Elk King fixes Level 03's terminal presentation. Elk King Defeat prevents any later Player Defeat, while an already confirmed Player Defeat prevents Elk King Death Staging from starting; neither result can replace the other afterward.
_Avoid_: Simultaneous terminal presentations, late outcome replacement

**Elk Shield**:
A passive, rechargeable protection possessed by an Elk or Elk King that negates one otherwise applicable incoming damage event, regardless of the damage source, while the protection is available. Damage already rejected by another immunity or invalid actor state does not consume it; negating damage starts a Shield Break Window without changing health or causing knockback.
_Avoid_: Weapon block, damage immunity

**Elk Shield Cooldown**:
The fixed five-second interval after an Elk's Shield Break Window ends and before its shield becomes visible and available again. Damage received during this interval is resolved normally and neither resets nor extends it.
_Avoid_: Thunder cooldown, hurt immunity

**Player Shield**:
A passive, rechargeable protection possessed by Player 04 that begins each Level instance available and negates one otherwise applicable incoming damage event, regardless of the damage source. Damage already rejected by another immunity or invalid actor state does not consume it; negating damage starts a Shield Break Window without changing health or causing knockback.
_Avoid_: Elk Shield, damage immunity, weapon block

**Shield Break Window**:
The interval in which a spent Player or Elk Shield presents its break and rejects every further damage event without causing a hit reaction, knockback, action interruption, or loss of Player control. It lasts until that presentation finishes; further hits do not repeat or change its presentation or timing, after which the corresponding Shield Cooldown begins and a still-valid Persistent Damage Contact may immediately damage the Player without requiring contact re-entry.
_Avoid_: Shield Cooldown, hurt immunity, reusable protection

**Player Shield Cooldown**:
The fixed ten-second interval after Player 04's Shield Break Window ends and before the Player Shield becomes visible and available again. Damage received during this interval is resolved normally and neither resets nor extends it.
_Avoid_: Elk Shield Cooldown, hurt immunity
