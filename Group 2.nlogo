globals [
                ; infection rate for Party A -> Party B
                ; infection rate for Party B -> Party A
                ; infection rate for losing interest
                ; recovery rate (prob of going back to suceptible?)
                ; probability an infected agent actually shares
                ; number of initial sharers
  rand-seed     ; for replicability
                ; number of agents
                ; predefined voting percentage
]

; Define agent breed
breed [youths youth]

; Youth attributes
youths-own [
  voting-status    ; "will-vote", "will-not-vote"
  party            ; "A" / "B" / "None"
  friends          ; list within radius 1
  followers        ; list with 1 < r <= 2
  others           ; list with r > 2
  shared?          ; has shared content?
  content-bias     ; "neutral" / "partyA" / "partyB"
  sir-state        ; "susceptible" / "infected"
]
to export-csv [filename]
  let filepath (word (user-directory) filename)
  file-open filepath
  ; write column headers
  file-print "who,voting-status,party,sir-state,shared?,content-bias,xcor,ycor"

  ; write one line per youth
  ask youths [
    file-print (word who "," voting-status "," party "," sir-state "," shared? "," content-bias "," xcor "," ycor)
  ]
  file-close
end


; --------------------------
; Setup procedure
; --------------------------
to setup
  clear-all

  ;; Replicability
  set rand-seed 12345       ;; fixed number for replicable runs
  random-seed rand-seed     ;; ensures same output if repeated

  set n-agents 500
  set initial-seeds n-agents / 10
  set percent-will-vote 75
  set beta1 0.2
  set beta2 0.3
  set beta3 0.1
  set p-share 0.5
  set gamma 0.05  ;; recovery rate: 5% chance per tick to become susceptible again

  create-youths n-agents [
    setxy random-xcor random-ycor
    set shape "person"
    set shared? false
    set content-bias "neutral"
    set sir-state "susceptible"
    set friends no-turtles      ;;  always an agentset
    set followers no-turtles
    set others no-turtles

    ifelse random-float 100 < percent-will-vote [
      set voting-status "will-vote"
      set party one-of ["A" "B"]
    ][
      set voting-status "will-not-vote"
      set party one-of ["A" "B" "None"]
    ]

    recolor-agent
  ]

  ; --- Seed initial sharers ---
  let seeds n-of initial-seeds youths with [sir-state = "susceptible"]
  ask seeds [
    if not shared? [   ;; prevent reseeding the same youth
      if party = "A" [ share-content "partyA" ]
      if party = "B" [ share-content "partyB" ]
      set sir-state "infected"   ;; ensure infection state is set
    ]
  ]

  reset-ticks
  export-csv "setup-output.csv"

end

; --------------------------
; Social categorization
; --------------------------
to define-connections
  ask youths [
    set friends youths in-radius 1 with [self != myself]
    set followers youths with [distance myself > 1 and distance myself <= 2]
    set others youths with [distance myself > 2]
  ]
end

; --------------------------
; Coloring rules
; --------------------------
to recolor-agent
  if voting-status = "will-not-vote" [
    set color green     ;; all non-voters appear green regardless of party
  ]
  if voting-status = "will-vote" [
    if party = "A" [ set color red ]
    if party = "B" [ set color blue ]
    if party = "None" [ set color grey ]   ;; neutral voters shown grey & ADD NUETRAL AGENTS AND SEE THEIR CHANGE
  ]
end


; --------------------------
; Sharing procedure
; --------------------------
to share-content [bias]
  ;; rule: neutral non-voters cannot share
  if voting-status = "will-not-vote" and party = "None" [ stop ]

  set shared? true
  set content-bias bias
  set sir-state "infected"
end

; --------------------------
; Spreading process
; --------------------------


; --------------------------
; Main loop
; --------------------------

to spread-content
  ;; Step 1: Infected agents who have already shared spread ideology to neighbors
  ask youths with [sir-state = "infected" and shared? = true] [
    ;; Expose neighbors (susceptibles within distance 3)
    let targets youths with [sir-state = "susceptible" and distance myself <= 3]

    ask targets [
      ;; --- Ideology updates ---
      if party = "A" [
        if [content-bias] of myself = "partyB" [
          if random-float 1 < beta1 [
            set party "B"
            recolor-agent
          ]
        ]
        if [content-bias] of myself = "neutral" [
          if random-float 1 < beta3 [
            set party "None"
            recolor-agent
          ]
        ]
      ]

      if party = "B" [
        if [content-bias] of myself = "partyA" [
          if random-float 1 < beta2 [
            set party "A"
            recolor-agent
          ]
        ]
        if [content-bias] of myself = "neutral" [
          if random-float 1 < beta3 [
            set party "None"
            recolor-agent
          ]
        ]
      ]

      ;; --- Infection process (SIS part) ---
      set sir-state "infected"
      ;; New infected agents may or may not become sharers
      if random-float 1 < p-share [
        set shared? true
        set content-bias [content-bias] of myself
      ]
    ]
  ]
end

; --------------------------
; Voting Intention Update
; --------------------------
to update-voting-intention
  ask youths [
    let influence 0
    let old-status voting-status   ;; remember before update

    ;; --- Content exposure effect ---
    if shared? [
      if content-bias = "partyA" or content-bias = "partyB" [
        set influence influence + 0.1   ;; partisan content motivates voting
      ]
      if content-bias = "neutral" [
        set influence influence - 0.1   ;; neutral content reduces motivation
      ]
    ]

    ;; --- Peer influence effect ---
    let pro-vote count friends with [voting-status = "will-vote"]
    let anti-vote count friends with [voting-status = "will-not-vote"]

    if pro-vote > anti-vote [ set influence influence + 0.1 ]
    if anti-vote > pro-vote [ set influence influence - 0.1 ]

    ;; --- Engagement effect ---
    if shared? [ set influence influence + 0.2 ]

    ;; --- Update voting-status probabilistically ---
    if influence > 0 [
      set voting-status "will-vote"
    ]

    if influence < 0 [
      set voting-status "will-not-vote"
    ]

    ;; --- Apply party rules ONLY if status changed ---
    if voting-status != old-status [

      ;; Case 1: Became will-vote → must be A or B
      if voting-status = "will-vote" [
        if party = "None" [
          ;; choose party from peers if possible
          let nearbyA count friends with [party = "A"]
          let nearbyB count friends with [party = "B"]
          if nearbyA > nearbyB [ set party "A" ]
          if nearbyB > nearbyA [ set party "B" ]
          if nearbyA = nearbyB [ set party one-of ["A" "B"] ] ;; tie-break
        ]
      ]

      ;; Case 2: Became will-not-vote → can be A, B, or None
      if voting-status = "will-not-vote" [
        ;; Priority 1: if shared content, stay aligned with it
        if shared? [
          if content-bias = "partyA" [ set party "A" ]
          if content-bias = "partyB" [ set party "B" ]
        ]
        ;; Priority 2: peer influence
        if not shared? [
          let nearbyA count friends with [party = "A"]
          let nearbyB count friends with [party = "B"]
          if nearbyA > nearbyB [ set party "A" ]
          if nearbyB > nearbyA [ set party "B" ]
          if nearbyA = nearbyB [ set party "None" ] ;; stays neutral if tie
        ]
      ]
    ]
    recolor-agent
  ]
end


to go
  ;; Step 1: Spread content (infectious process)
  spread-content

  ;; Step 2: Recovery (agents become susceptible again)
  ask youths with [sir-state = "infected"] [
    if random-float 1 < gamma [
      ;; Become susceptible again but keep current ideology
      set sir-state "susceptible"
      set shared? false
      ;set content-bias "neutral"   ;; drop the content they were sharing (NOT NECESSARY)
    ]
  ]

  ;; Step 3: Update voting intention dynamically
  update-voting-intention

  tick

  if ticks >= 90 [
  export-csv "final-output.csv"
  stop
]


end
@#$#@#$#@
GRAPHICS-WINDOW
260
38
697
476
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
-16
16
-16
16
0
0
1
ticks
30.0

BUTTON
72
72
135
105
NIL
setup\n
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
71
123
134
156
NIL
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
24
191
196
224
percent-will-vote
percent-will-vote
0
100
75.0
5
1
NIL
HORIZONTAL

SLIDER
24
241
196
274
beta1
beta1
0
1
0.2
0.05
1
NIL
HORIZONTAL

SLIDER
24
288
196
321
beta2
beta2
0
1
0.3
0.05
1
NIL
HORIZONTAL

SLIDER
24
336
196
369
beta3
beta3
0
1
0.1
0.05
1
NIL
HORIZONTAL

SLIDER
23
386
195
419
gamma
gamma
0
1
0.05
0.01
1
NIL
HORIZONTAL

SLIDER
21
435
193
468
p-share
p-share
0
1
0.5
0.05
1
NIL
HORIZONTAL

INPUTBOX
21
500
254
560
n-agents
500.0
1
0
Number

INPUTBOX
299
502
518
562
initial-seeds
50.0
1
0
Number

PLOT
917
53
1117
203
Voting Intention Over Time
ticks
counts
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"Will-vote" 1.0 0 -7500403 true "" "plot count youths with [voting-status = \"will-vote\"]"
"Will-not-vote" 1.0 0 -2674135 true "" "plot count youths with [voting-status = \"will-not-vote\"]"

PLOT
920
257
1120
407
Party Support Over Time
ticks
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"Party A" 1.0 0 -2674135 true "" "plot count youths with [party = \"A\"]"
"Party B" 1.0 0 -10649926 true "" "plot count youths with [party = \"B\"]"
"Neutral" 1.0 0 -11085214 true "" "plot count youths with [party = \"None\"]"

@#$#@#$#@
Youth Voter Turnout Simulation
==============================

WHAT IS IT?
-----------
This model simulates youth voter turnout dynamics in a two-party election (Party A and Party B) using an agent-based approach.
It explores how social influence, media sharing, and peer interactions affect both party affiliation and voting intention over time.

HOW IT WORKS
------------
The model is based on combining social contagion dynamics with voter behavior:

- Agents (youths)
  Each youth has attributes such as voting intention ("will-vote" / "will-not-vote"), 
  party alignment ("A", "B", or "None"), content-sharing status, and epidemic-like exposure 
  state ("susceptible" / "infected"). Social connections are classified into:
	- friends (radius ≤ 1)
	- followers (1 < r ≤ 2)
	- others (r > 2)
- Epidemic-style spreading
  Infected youths (sharers) expose nearby agents to partisan or neutral content.
  Exposure can cause party switching (A ↔ B) or loss of interest (becoming neutral).
- Recovery
  Infected agents may recover at rate gamma, becoming susceptible again while keeping their party identity.
- Voting intention updates
  * Content exposure: partisan boosts voting motivation, neutral reduces it.
  * Peer influence: majority of friends can shift voting intention.
  * Engagement: sharing content increases the chance of being a voter.

**Iteration**
  The model runs in ticks, with spreading, recovery, and voting updates occurring each step.
  After 90 ticks, results are exported for analysis.

HOW TO USE IT
-------------
### Press SETUP
- Initializes a youth population (n-agents) with random positions, party alignment, and voting intentions.
- Seeds some agents (initial-seeds) as initial sharers.

### Press GO
   - Starts the simulation.
   - Agents spread content, recover, and update their voting decisions.
   - Runs until 90 ticks, then stops automatically.

### Outputs
   - setup-output.csv: population snapshot immediately after setup.
   - final-output.csv: final population snapshot after 90 ticks.
   Each file includes: agent ID, voting status, party alignment, infection state, sharing status, content bias, and position.

PARAMETERS
----------
### Epidemic-style spread factors:
-**beta1**: Probability that a Party A supporter switches to Party B.
-**beta2**: Probability that a Party B supporter switches to Party A.
-**beta3**: Probability that neutral content reduces partisan loyalty.
-**p-share**: Probability that an infected agent actually shares.
-**gamma**: Recovery rate – probability of returning to susceptible.

### Demographic setup:
- **n-agents**: Number of youth agents.
- **initial-seeds**: Number of initial sharers.
- **percent-will-vote**: Proportion of voters at setup.
- **rand-seed: Random seed** for replicability.

THINGS TO NOTICE
----------------
- How quickly do Party A or Party B spread their influence?
- Does neutral content reduce engagement significantly compared to partisan content?
- Which grows faster: party switching or disengagement (will-not-vote)?

THINGS TO TRY
-------------
- Vary p-share (sharing probability). What happens when sharing is rare vs. very common?
- Change beta1 and beta2 to make one party more persuasive than the other.
- Increase percent-will-vote to test scenarios with highly engaged vs. disengaged populations.
- Experiment with gamma (recovery rate). Does faster recovery weaken the spread of partisan content?

EXTENDING THE MODEL
-------------------
- Add media agents or influencers that broadcast partisan messages beyond friend networks.
- Introduce youth demographics (e.g., urban vs. rural, educated vs. less educated).
- Track aggregate statistics such as total voters, party balance, and turnout percentages over time.
- Explore the effect of bot agents that spread biased content persistently.

RELATED MODELS
--------------
- Epidemic models (e.g., Virus, HIV).
- Social influence models (e.g., Rumor Mill).
- Voting/Political models in the NetLogo library.

CREDITS AND REFERENCES
----------------------
Developed for exploring the intersection of social influence, youth political participation,
and epidemic-style spreading. Inspired by social contagion theory and agent-based modeling approaches.
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
