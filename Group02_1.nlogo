;==Youth voter turnout via Social media==

;==Globals==
globals [
  friend-radius
  follower-radius
  ;K
  ;r
  ;d
  like-boost
  share-boost
  post-creation-rate
  susceptibility-decay
  pulse-duration
  ;fading-links-on?
  increased-decay-rate
  decay-age-threshold
  select-post-weight-id
]

;==Breeds==
breed [youths youth]
breed [nonyouths nonyouth]
breed [posts post]

;==Agent attributes==
youths-own [
  p_A p_B p_N
  engagement
  voting-intention
  susceptibility
  ideology
  my-friends
  my-followers
]

nonyouths-own [
  p_A p_B p_N
  engagement
  voting-intention
  susceptibility
  ideology
  my-friends
  my-followers
]

posts-own [
  category
  weight
  age
  owner-id
  likes
  shares
  peak-reached?
]

;==Links for temporary interactions==
links-own [ lifetime max-lifetime ]  ;; track fading links

;==Setup==
to setup
  clear-all

  ;Create youth agents
  create-youths 500 [
    setxy random-xcor random-ycor
    init-youth-attributes
    set shape "person"
    set size 1.2
    color-by-ideology
  ]

  ;Create non-youth agents
  create-nonyouths 100 [
    setxy random-xcor random-ycor
    init-nonyouth-attributes
    set shape "person"
    set size 1.0
    color-by-ideology
  ]

  ;Create initial posts
  create-initial-posts

  random-seed 12345
  set friend-radius 2
  set follower-radius 4
  ;set K 20
  ;set r 0.4
  ;set d 0.08
  set like-boost 0.2
  set share-boost 0.5
  set post-creation-rate 0.08
  set susceptibility-decay 0.01
  set pulse-duration 1
  ;set fading-links-on? true
  set increased-decay-rate 0.5
  set decay-age-threshold 20

  social-connections
  set select-post-weight-id [who] of one-of posts
  export-csv "setup-output.csv"
  reset-ticks
end

;==Initialization==
to init-youth-attributes
  let a random-float 1
  let b random-float 1
  let n random-float 1
  let total (a + b + n)
  set p_A a / total
  set p_B b / total
  set p_N n / total
  set engagement random 11
  set susceptibility 0.4 + random-float 0.6
  set voting-intention (random-float 1 < 0.6)
  determine-ideology
  set my-friends no-turtles
  set my-followers no-turtles
end

to init-nonyouth-attributes
  let a random-float 1
  let b random-float 1
  let n random-float 1
  let total (a + b + n)
  set p_A a / total
  set p_B b / total
  set p_N n / total
  set engagement random 9
  set susceptibility 0.1 + random-float 0.5
  set voting-intention (random-float 1 < 0.8)
  determine-ideology
  set my-friends no-turtles
  set my-followers no-turtles
end

to create-initial-posts
  let all-agents (turtle-set youths nonyouths)
  ask n-of 20 all-agents [
    create-post-from-agent
  ]
end

;==Agent creates a post==
to create-post-from-agent
  hatch-posts 1 [
    setxy [xcor] of myself [ycor] of myself
    set category get-post-category [ideology] of myself
    set weight 1 + random-float 2
    set age 0
    set owner-id [who] of myself
    set shape "circle"
    set size 0.5
    set likes 0
    set shares 0
    set peak-reached? false

    if category = "partyA" [ set color red + 2 ]
    if category = "partyB" [ set color blue + 2 ]
    if category = "neutral" [ set color white + 2 ]
  ]
end

;==Post Category==
to-report get-post-category [agent-ideology]
  let rand random-float 1
  if agent-ideology = "A" [
    if rand < 0.8 [ report "partyA" ]
    if rand < 0.95 [ report "neutral" ]
    report "partyB"
  ]
  if agent-ideology = "B" [
    if rand < 0.8 [ report "partyB" ]
    if rand < 0.95 [ report "neutral" ]
    report "partyA"
  ]
  if rand < 0.7 [ report "neutral" ]
  if rand < 0.85 [ report "partyA" ]
  report "partyB"
end

;==Ideology==
to determine-ideology
  if abs(p_A - p_B) < 0.1 and p_N > 0.4 [ set ideology "None" stop ]
  if (p_A >= p_B) and (p_A >= p_N) [ set ideology "A" ]
  if (p_B > p_A) and (p_B >= p_N) [ set ideology "B" ]
  if (p_N > p_A) and (p_N > p_B) [ set ideology "None" ]
end

;==Color Assignment==
to color-by-ideology
  if ideology = "A" [
    ifelse breed = youths [ set color red ] [ set color red - 2 ]
  ]
  if ideology = "B" [
    ifelse breed = youths [ set color blue ] [ set color blue - 2 ]
  ]
  if ideology = "None" [
    ifelse breed = youths [ set color white ] [ set color white - 2 ]
  ]
end

;==Social connections==
to social-connections
  ask (turtle-set youths nonyouths) [
    let all-other-agents (turtle-set youths nonyouths) with [self != myself]
    set my-friends all-other-agents with [distance myself < friend-radius]
    set my-followers all-other-agents with [
      (distance myself >= friend-radius) and (distance myself < follower-radius)
    ]
  ]
  print (word "Average friends per agent: " round (mean [count my-friends] of (turtle-set youths nonyouths)))
  print (word "Average followers per agent: " round (mean [count my-followers] of (turtle-set youths nonyouths)))
end

;==GO==
to go
  ask (turtle-set youths nonyouths) [
    check-social-media-posts

    if random-float 1 < post-creation-rate [
      create-post-from-agent
    ]

    set susceptibility susceptibility - susceptibility-decay
    if susceptibility < 0.1 [ set susceptibility 0.1 ]

    update-voting-intention
  ]

  ask posts [
    update-post-logistic-growth
    set age age + 1
    if age > 50 or weight < 0.1 [ die ]
  ]

  fade-temporary-links  ;; fade links created this tick
  revert-agent-sizes    ;; revert agent sizes after pulse
  update-display

  display
  tick
  if ticks >= 90 [
    export-csv "final-output.csv"
    stop]
end

to revert-agent-sizes
  ask (turtle-set youths nonyouths) [
    if breed = youths [ set size 1.2 ]
    if breed = nonyouths [ set size 1.0 ]
  ]
end

; ===== LOGISTIC GROWTH MODEL FOR POSTS =====
to update-post-logistic-growth
  let current-decay-rate d
  if peak-reached? or age >= decay-age-threshold [
    set current-decay-rate increased-decay-rate
  ]
  let growth-term (r * weight * (1 - weight / K))
  let decay-term (current-decay-rate * weight)
  set weight weight + growth-term - decay-term

  ; Smoothed boost
  set weight weight + ((likes * like-boost) + (shares * share-boost)) * 0.5
  set likes 0
  set shares 0

  if weight > K [ set weight K set peak-reached? true ]
  if weight < 0 [ set weight 0 ]
  set size 0.4 + 0.1 * (weight / K)
end

;==Social media check==
to check-social-media-posts
  let me self
  let relevant-posts posts with [
    member? owner-id [who] of [my-friends] of me or
    member? owner-id [who] of [my-followers] of me
  ]

  if any? relevant-posts [
    let target-post weighted-random-post relevant-posts
    if target-post != nobody [
      let is-from-friend? member? [owner-id] of target-post [who] of [my-friends] of me
      let base-strength ifelse-value is-from-friend? [0.8] [0.3]
      let alignment get-post-alignment target-post
      let final-strength base-strength * (0.5 + 0.5 * alignment)
      if random-float 1 < (susceptibility * final-strength) [
        interact-with-post target-post is-from-friend?
      ]
    ]
  ]
end

;==Post alignment==
to-report get-post-alignment [target-post]
  let post-cat [category] of target-post
  if post-cat = "partyA" [ report (p_A - p_B) ]
  if post-cat = "partyB" [ report (p_B - p_A) ]
  if post-cat = "neutral" [ report p_N ]
  report 0
end

;==Interact with post with fading links==
to interact-with-post [target-post is-friend?]
  ask target-post [ set likes likes + 1 ]

  let share-prob 0.2
  if is-friend? [ set share-prob share-prob + 0.3 ]
  let alignment get-post-alignment target-post
  if alignment > 0 [ set share-prob share-prob + (alignment * 0.4) ]

  if random-float 1 < share-prob [
    hatch-posts 1 [
      setxy [xcor] of myself [ycor] of myself
      set category [category] of target-post
      set weight 0.8 + random-float 0.5
      set age 0
      set owner-id [who] of myself
      set likes 0
      set shares 0
      set peak-reached? false
      set shape "circle"
      set size 0.3
      if category = "partyA" [ set color red ]
      if category = "partyB" [ set color blue ]
      if category = "neutral" [ set color white ]
    ]

    ; Create fading link from sharer to post owner
    create-link-with turtle [owner-id] of target-post [
      set color yellow
      set thickness 0.55  ;; Thicker for pulse
      set lifetime 5
      set max-lifetime 5
    ]
    set size size * 1.5  ;; Sharer pulses
    ask turtle [owner-id] of target-post [ set size size * 1.5 ]  ;; Post owner pulses.
  ]

  let influence-strength ifelse-value is-friend? [0.5 * [weight] of target-post / K] [0.2 * [weight] of target-post / K]
  set susceptibility susceptibility + 0.02 * ([weight] of target-post / K)
  if susceptibility > 1 [ set susceptibility 1 ]

  update-ideology-from-post [category] of target-post influence-strength
end

;==Weighted random post==
to-report weighted-random-post [post-set]
  if not any? post-set [ report nobody ]
  let total-weight sum [weight] of post-set
  if total-weight <= 0 [ report one-of post-set ]
  let random-weight random-float total-weight
  let cumulative-weight 0
  let selected-post nobody
  ask post-set [
    if selected-post = nobody [
      set cumulative-weight cumulative-weight + weight
      if cumulative-weight >= random-weight [ set selected-post self ]
    ]
  ]
  report selected-post
end

;==Update voting intention==
to update-voting-intention
  let partisan-strength (p_A + p_B)
  let base-intention partisan-strength * (0.3 + 0.7 * (engagement / 10))
  let social-boost susceptibility * 0.3
  let final-intention base-intention + social-boost
  if final-intention > 0.7 [ set voting-intention true ]
  if final-intention < 0.3 [ set voting-intention false ]
end

;==Update ideology==
to update-ideology-from-post [post-category influence]
  let change-amount influence-rate * influence
  if post-category = "partyA" [
    set p_A p_A + change-amount
    set p_B p_B - (change-amount / 2)
    set p_N p_N - (change-amount / 2)
  ]
  if post-category = "partyB" [
    set p_B p_B + change-amount
    set p_A p_A - (change-amount / 2)
    set p_N p_N - (change-amount / 2)
  ]
  if post-category = "neutral" [
    set p_N p_N + change-amount
    set p_A p_A - (change-amount / 2)
    set p_B p_B - (change-amount / 2)
  ]

  if p_A < 0 [ set p_A 0 ]
  if p_B < 0 [ set p_B 0 ]
  if p_N < 0 [ set p_N 0 ]

  let total (p_A + p_B + p_N)
  if total > 0 [
    set p_A p_A / total
    set p_B p_B / total
    set p_N p_N / total
  ]

  determine-ideology
  color-by-ideology
end

;==Fade temporary links at each tick==
to fade-temporary-links
  if fading-links-on? [
    ask links [
      if lifetime > 0 [
        set lifetime lifetime - 1
        set thickness 0.5 * (lifetime / max-lifetime)
        set color scale-color yellow lifetime 0 max-lifetime
        if lifetime <= 0 [ die ]
      ]
    ]
  ]
  if not fading-links-on? [
    ask links [ die ] ;; If switch is off, remove all links immediately
  ]
end

to update-display
  if watch-a-person? and subject = nobody
    [ watch one-of turtles with [ not hidden? ]
      clear-drawing
      ask subject [ pen-down ]
      inspect subject ]
  if not watch-a-person? and subject != nobody
    [ stop-inspecting subject
      ask subject
        [ pen-up
          ask my-links [ die ] ]
      clear-drawing
      reset-perspective ]
end


; ===== CSV EXPORT =====
to export-csv [filename]
  file-open filename
  ; header
  file-print "id,breed,ideology,p_A,p_B,p_N,engagement,susceptibility,voting_intention,xcor,ycor"

  ask (turtle-set youths nonyouths) [
    file-print (word who "," breed "," ideology ","
      p_A "," p_B "," p_N ","
      engagement "," susceptibility ","
      voting-intention "," xcor "," ycor)
  ]
  file-close
end
@#$#@#$#@
GRAPHICS-WINDOW
220
11
761
553
-1
-1
13.0
1
10
1
1
1
0
1
1
1
-20
20
-20
20
0
0
1
ticks
30.0

BUTTON
24
10
90
43
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
126
12
189
45
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
22
60
194
93
r
r
0.01
1
0.4
0.01
1
NIL
HORIZONTAL

SLIDER
21
101
193
134
d
d
0.01
1
0.08
0.01
1
NIL
HORIZONTAL

SLIDER
20
141
192
174
K
K
1
100
20.0
1
1
NIL
HORIZONTAL

PLOT
779
23
1151
173
Ideology Distribution (Youths)
ticks
count
0.0
90.0
0.0
150.0
true
true
"" ""
PENS
"A-youth" 1.0 0 -2674135 true "" "plot count youths with [ideology = \"A\"]"
"B-youth" 1.0 0 -13345367 true "" "plot count youths with [ideology = \"B\"]"
"N-youth" 1.0 0 -14439633 true "" "plot count youths with [ideology = \"None\"]"

PLOT
778
204
1152
354
Voting Intention (Youths)
ticks
Count
0.0
90.0
0.0
300.0
true
true
"" ""
PENS
"True" 1.0 0 -14835848 true "" "plot count youths with [voting-intention = true]"
"False" 1.0 0 -3844592 true "" "plot count youths with [voting-intention = false]"

PLOT
780
386
1153
536
Post Weight vs Time
ticks
weight
0.0
90.0
0.0
30.0
true
false
"" ""
PENS
"weight" 1.0 0 -16777216 true "" "; Ensure 'select-post-weight-id' is set to a who value of a post that exists.\nif any? posts [\n  if member? select-post-weight-id [who] of posts [\n    let target-post one-of posts with [who = select-post-weight-id]\n    if target-post != nobody [\n      plot [weight] of target-post\n    ]\n  ]\n]"

SWITCH
42
224
166
257
fading-links-on?
fading-links-on?
0
1
-1000

CHOOSER
32
347
170
392
turtle-shape
turtle-shape
"person" "circle"
0

SWITCH
42
306
165
339
show-age?
show-age?
1
1
-1000

SWITCH
42
264
166
297
watch-a-person?
watch-a-person?
0
1
-1000

SLIDER
19
182
191
215
influence-rate
influence-rate
0
1
0.71
0.01
1
NIL
HORIZONTAL

MONITOR
12
409
98
454
Youths --> A
count youths with [ideology = \"A\"]
17
1
11

MONITOR
107
408
189
453
Youths -->B
count youths with [ideology = \"B\"]
17
1
11

MONITOR
0
463
93
508
Youths voting
count youths with [voting-intention = true]
17
1
11

MONITOR
103
463
220
508
Youths not-voting
count youths with [voting-intention = false]
17
1
11

MONITOR
121
516
199
561
Num posts
count posts
17
1
11

MONITOR
9
516
112
561
Youth --> None
count youths with [ideology = \"None\"]
17
1
11

@#$#@#$#@
# ODD Protocol for “Youth Voter Turnout and Political Polarization via Social Media” Model


## 1. Purpose

The purpose of this model is to explore how social media interactions affect the political engagement and voting intentions of youth and non-youth populations. Specifically, the model investigates the spread of political posts, how agent susceptibility and ideology evolve over time, and how these influence overall voter turnout. The model is intended for studying the dynamics of online influence, partisan polarization, and the role of social connectivity in shaping democratic participation.

## 2. Entities, State Variables, and Scales

### Entities

#### _Agents_

 * Youths (primary focus of the model, representing young voters)

 * Non-youths (older or less digitally active individuals)

 * Posts (social media messages with ideological content)

#### _Links_

 * Temporary links between agents created through interactions such as sharing posts.

### State Variables

#### _Youth and Nonyouth agents_

 * `p_A, p_B, p_N` – probabilities representing support for Party A, Party B, or Neutral stance.

 * `engagement` – how active the agent is in social media interactions.

 * `voting-intention` – Boolean indicator of intention to vote.

 * `susceptibility` – degree of openness to influence from social media posts.

 * `ideology` – categorical label (“A”, “B”, or “None”) based on probabilities.

 * `my-friends, my-followers` – sets of neighboring agents based on spatial distance.

#### _Posts_

 * `category` – ideological label (“partyA”, “partyB”, or “neutral”).

 * `weight` – strength/visibility of the post (subject to logistic growth and decay).

 * `age` – how long the post has existed.

 * `owner-id` – ID of the agent that created the post.

 * `likes, shares` – counters of engagement actions.

 * `peak-reached?` – whether the post has reached maximum popularity.

#### _Links_

 * `lifetime, max-lifetime` – duration of temporary links created during sharing.

### Scales

 * Spatial scale: Agents are placed in a 2D NetLogo world; interactions are defined by spatial distance (friend-radius and follower-radius).

 * Temporal scale: Time advances in discrete ticks. Each tick corresponds to one unit of time during which agents can post, share, and update states.


## 3. Process Overview and Scheduling

Each simulation tick proceeds as follows:

### *1. Agent actions (youths and non-youths):*

   * Check social media for posts from friends/followers.

   * With some probability, create a new post.

   * Update susceptibility by applying natural decay.

   * Update voting intention based on ideology, engagement, and susceptibility.

### *2. Posts:*

   * Update their weight using a logistic growth and decay function.

   * Increase age, and be removed if too old or weak.

### *3. Links:*

   * Fade and disappear as their lifetimes expire.

### *4. Display updates:*

   * Adjust colors and sizes of agents and posts.

   * Apply pulsing effect during sharing.
 
### *5. Stopping condition:* 

   * Simulation stops after a fixed number of ticks (e.g., 90), and results are exported to CSV.


## 4. Design Concepts

#### Basic principles: 
The model is grounded in theories of social influence, opinion dynamics, and digital political communication. It assumes that online posts influence susceptibility, which in turn shifts ideology and voting intention.

#### Emergence: 
Population-level outcomes such as voter turnout rates and ideological polarization emerge from local interactions between agents and posts.

#### Adaptation: 
Agents adjust ideology and voting intention based on the alignment and strength of the posts they interact with.

#### Objectives: 
Agents seek to maintain or update political alignment, indirectly aiming to maximize congruence with their environment.

#### Learning: 
Agents do not explicitly learn, but probabilities (`p_A, p_B, p_N`) are updated dynamically in response to social exposure.

#### Prediction: 
Not explicitly modeled; decisions are probabilistic.

#### Sensing: 
Agents sense posts from their friends and followers based on proximity.

#### Interaction: 
Agents interact through likes, shares, and temporary links that represent social engagement.

#### Stochasticity: 
Randomness is present in initialization, posting decisions, post categories, susceptibility changes, and weighted random post selection.

#### Collectives: 
Agents form implicit social clusters through friend/follower networks.

#### Observation: 
Output is exported as CSV containing ideological states, susceptibility, and voting intention of agents.


## 5. Initialization

### Agents:

  * 500 youths and 100 non-youths are created at random positions.

  * Each agent’s ideology probabilities (`p_A, p_B, p_N`), engagement, susceptibility, and voting intention are initialized randomly within given ranges.

### Posts:

  * 20 initial posts are created from randomly selected agents, colored by ideological category.

### Parameters:

  * Key parameters such as `friend-radius, follower-radius, like-boost, share-boost, post-creation-rate, susceptibility-decay`, and logistic growth constants are set.

### Social network:

  * Each agent’s friends and followers are determined by spatial distance.

### Random seed:

  * A fixed seed ensures reproducibility.


## 6. Input Data

The model does not require external input datasets. All agent attributes and posts are initialized stochastically based on parameter values. Parameters can be modified by the user to explore different scenarios (e.g., higher posting rate, stronger susceptibility decay).


## 7. Submodels

### a. Post Category Assignment

Determines the ideological category of posts based on the ideology of the agent and a probability distribution.

### b. Logistic Growth of Posts

Post weights evolve according to logistic growth with decay, modulated by likes and shares. Posts eventually fade out when weight or age thresholds are reached.

### c. Social Media Check

Agents evaluate relevant posts, calculate influence strength, and probabilistically decide to like or share.

### d. Interaction with Posts

Agents may like or share posts. Sharing creates new posts and temporary links, and increases susceptibility and ideology alignment.

### e. Ideology Update

Probabilities (`p_A, p_B, p_N`) are updated according to influence strength from posts, then normalized and mapped to an ideology label.

### f. Voting Intention Update

Voting intention is recalculated based on engagement, susceptibility, and partisan strength.

### g. Link Fading

Temporary interaction links decay over time and are removed once their lifetime reaches zero.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Analysis of r" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count youths with [ideology = "A"]</metric>
    <metric>count youths with [ideology = "B"]</metric>
    <metric>count youths with [ideology = "None"]</metric>
    <metric>count posts</metric>
    <metric>count youths with [voting-intention = true]</metric>
    <metric>count youths with [voting-intention = false]</metric>
    <enumeratedValueSet variable="r">
      <value value="0.1"/>
      <value value="0.2"/>
      <value value="0.3"/>
      <value value="0.4"/>
      <value value="0.5"/>
      <value value="0.6"/>
      <value value="0.7"/>
      <value value="0.8"/>
      <value value="0.9"/>
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
