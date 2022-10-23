breed [ attractions attraction ]
breed [ tourists tourist ]
breed [ entrances entry ]
globals [ patch-data path-file elevation-data elevation-file time day-length current-tourists happiness-avg happiness-count]
patches-own [ path? vegetation-health lake? elevation trampled? max-health dist-goals dead?]
tourists-own [ goal adheres? path-plan deviation-pos return-pos exploration-start happiness]

to setup
  clear-all
  set path-file "alltracks.txt"
  set elevation-file "elevation.txt"
  set-default-shape attractions "flag"
  set-default-shape tourists "person"
  set-default-shape entrances "square"
  ask patches [ set pcolor green ]
  load-patch-data
  set-patch-elevation
  place-attractions

  calculate-path-distances

  set time 0
  set happiness-avg 0
  set happiness-count 1

  ;; one square is 11 metres - walk at ~4kmh = ~1ms-1 - square every ~12 seconds (because that's neater)
  set day-length 24 * 60 * 5 ;;One tick = 12 seconds

  reset-ticks
end

to go

  ;; Length of day
  if time >= day-length or (test-regrowth-after > 0 and ticks > test-regrowth-after) [
    set time 0
    ask tourists [tourist-remove]

    set current-tourists 0

    tick

    vetegation-growth
    recolor-patches

    ask patches with [trampled?] [set trampled? false]

  ]

  gen-tourists


  if count tourists > 0 [

    move-tourists ;; temp
  ]

  run-plots

  set time time + 1
end

to set-patch-elevation
  ifelse ( file-exists? elevation-file )
  [
    set elevation-data []
    file-open elevation-file
    while [ not file-at-end? ]
    [
      set elevation-data sentence elevation-data (list (list file-read file-read file-read))
    ]
    file-close
    ask patches [set elevation 900]
    foreach elevation-data [ three-tuple -> ask patch first three-tuple item 1 three-tuple [
      set elevation last three-tuple
      ask patches in-radius 20 [set elevation last three-tuple]
    ] ]
    repeat 20 [ diffuse elevation 1 ]
    ask patches [if pcolor != 95 and pcolor != 5  [
      set max-health round ((2000 - elevation) / 1200 * 100)
      let green-val (elevation - 600) / 1104 * 255
      set pcolor (list 0 green-val 0) ]
      set vegetation-health max-health
      set dead? false
    ]
    display
  ]
  [ user-message "Cannot find path file in current directory!" ]
end

to load-patch-data
  ifelse ( file-exists? path-file )
  [
    set patch-data []
    file-open path-file
    while [ not file-at-end? ]
    [
      set patch-data sentence patch-data (list (list file-read file-read file-read))
    ]
    file-close

    clear-patches
    clear-turtles
    foreach patch-data [ three-tuple -> ask patch first three-tuple item 1 three-tuple [ set pcolor last three-tuple ] ]
    ask patches [ifelse pcolor = 5 [set path? true] [set path? false]]
    ask patches [ifelse pcolor = 95 [set lake? true] [set lake? false]]
    ask patches [set trampled? false set dead? false]
    ask patches [set dist-goals [100000 100000 100000 100000 100000 100000 100000 100000 100000 100000 100000 100000]]
    display
  ]
  [ user-message "Cannot find path file in current directory!" ]
end

to place-attractions
  create-attractions 10 [set color yellow set size 10]
  ask attraction 0 [ setxy 240 -47 ] ;; cradle mountain peak
  ask attraction 1 [ setxy 94 129 ] ;; hansons peak
  ask attraction 2 [ setxy -2 -31 ] ;; marions lookout
  ask attraction 3 [ setxy -107 -100 ] ;; lookout
  ask attraction 4 [ setxy -48 -80 ] ;; lookout
  ask attraction 5 [ setxy -73 36 ] ;; boat shed
  ask attraction 6 [ setxy -68 80 ] ;; glacier rock
  ask attraction 7 [ setxy -110 -7 ] ;; lake lilla
  ask attraction 8 [ setxy 112 1 ] ;; lake wilks
  ask attraction 9 [ setxy 132 65 ] ;; ranges hut
  ; place entrances
  create-entrances 2 [set color gray]
  ask entry 10 [ setxy -108 52 set size 18] ;; Dove lake carpark
  ask entry 11 [ setxy -250 -69 set size 12] ;; Ronny creek carpark
end


;; Each path section stores the distance from it to each possible goal
to calculate-path-distances

  ask (turtle-set attractions entrances) [
    let goal-no who
    ask patches in-radius 5 with [path?] [
      set dist-goals replace-item goal-no dist-goals distance myself
      propogate-distances goal-no
    ]

  ]

end

;; Propogate distance to a goal to neighbouring path segments
to propogate-distances [goal-no]

  ask neighbors with [path?] [

    ;; Update closest distance to goal if new distance is less than already recorded

    if [item goal-no dist-goals] of myself <= item goal-no dist-goals - 2 [

      set dist-goals replace-item goal-no dist-goals ((item goal-no ([dist-goals] of myself)) + 1)
      ;set pcolor scale-color gray (item 11 dist-goals) 0 900

      ;; Recursively call to update this path's neighbours
      propogate-distances goal-no
    ]
  ]

end

to gen-tourists


  ;; Arrivals start 7am, peak 11am, end 3pm
  let hour (time / day-length) * 24
  let tourists-this-tick (tourist-count / (day-length / 3)) * 2 * ((- abs ((hour - 11) / 4)) + 1)

  if tourists-this-tick > 0 [

    set current-tourists current-tourists + tourists-this-tick
    let num-to-gen int (current-tourists - count tourists)

    ;; Dove lake carpark more popular - gets 80% of arrivals
    ifelse random-float 1 < 0.8 [
      ask [patch-here] of entry 10 [
        sprout-tourists (int num-to-gen) [tourist-init]
      ]
    ][
      ask [patch-here] of entry 11 [
        sprout-tourists (int num-to-gen) [tourist-init]
      ]
    ]


  ]

end

to tourist-init
  set goal one-of attractions
  set size 2
  set color yellow

  set adheres? random-float 100 > shortcutting-tourists

  if not adheres? [set color pink]

  set path-plan []
  set deviation-pos nobody
  set return-pos patch-here

  set happiness 100

  set exploration-start -1000

end

to tourist-remove
  set happiness-avg happiness-avg + happiness
  set happiness-count happiness-count + 1
  die
end

to vetegation-growth

  ask patches with [not trampled?] [
    ;Only regrow if not dead, or has healthy neighbours
    if not dead? or any? neighbors with [vegetation-health > 0.6 * max-health] [
      set vegetation-health min list (vegetation-health + ([vegetation-health] of max-one-of neighbors [vegetation-health] * vegetation-growth-rate / 100)) max-health
      if vegetation-health >= 5
      [ set dead? false ]
    ]
  ]

end

to vegetation-trampled
  set trampled? true
  if vegetation-health > 0 [set vegetation-health max list (vegetation-health - damage-per-step) 0]
end

to recolor-patches ;; mix of red and green

  ask patches with [ not path? and not lake?] [
    let green-val (elevation - 600) / 1104 * 255
    let red-val (max-health - vegetation-health) / 100 * 255

    set pcolor (list red-val green-val 0)

    if vegetation-health < 5 [set dead? true]


   ]
end

;; tourist code - copied from paths
to move-tourists
  ask tourists [

    if any? (patch-set [patch-here] of goal) in-radius 5 or ((time / day-length) * 24 > 18 and not member? goal entrances) [
      set exploration-start time

;      if any? (patch-set [patch-here] of goal) in-radius 5 and member? goal attractions [ ; increase happiness when goal is reached
;        set happiness happiness + 20
;      ]

      if member? goal entrances [
        tourist-remove
      ]

      ;; Go back to carpark after 4pm
      ifelse (time / day-length) * 24 > 16 [
        set goal min-one-of entrances [distance myself]
      ] [
        set goal one-of attractions
      ]
    ]
    walk-towards-goal

    ; change happiness depending on the amount of tourists around
    if count (other tourists) in-radius tourist-view-radius > 10 [set happiness happiness - 1 ] ;[set happiness happiness + 1 ]

    ; change happiness depending on the vegetation health
    ifelse count patches in-radius tourist-view-radius with [not path? and not lake? and dead?] / (tourist-view-radius * tourist-view-radius) > vegetation-unhappiness-threshold
    [ set happiness happiness - 1 ] [set happiness happiness + 1 ]

    ; keep within 0-100 range
    set happiness max list happiness 0
    set happiness min list happiness 100


  ]
end

to walk-towards-goal
  ask patch-here [ vegetation-trampled ]

  if length path-plan > 0 [
    move-to item 0 path-plan
    set path-plan but-first path-plan
    stop
  ]

  if deviation-pos = nobody and time - exploration-start < (attraction-exploration-time * 5) [
    set return-pos patch-here
    set deviation-pos one-of patches in-radius attraction-exploration-radius with [pcolor != 95]
  ]

  if deviation-pos = nobody and random-float 100 < deviation-chance and [path?] of patch-here [
    set return-pos patch-here
    set deviation-pos one-of patches in-radius 3 with [pcolor != 95]

  ]

  ifelse deviation-pos != nobody [
    face deviation-pos
    fd 1

    if patch-here = deviation-pos [

      ifelse deviation-pos = return-pos [

        set deviation-pos nobody
      ]
      [
        set deviation-pos return-pos
      ]
    ]

  ] [

    set heading best-way-to goal
    fd 1
  ]
end

to-report best-way-to [ destination ]


  ; of all the visible route patches, select the ones
  ; that would take me closer to my destination

  let goal-no ([who] of destination)

  if goal-no > 11 [report towards destination]

  let visible-patches patches in-radius 3
  let visible-routes visible-patches with [ path? ]

  let routes-that-take-me-closer visible-routes with [
    item goal-no dist-goals < [ item goal-no dist-goals - 1] of [patch-here] of myself
  ]

  ifelse any? routes-that-take-me-closer [
    ; from those route patches, choose the one that is the closest to me

    let next-path min-one-of routes-that-take-me-closer [ distance self ]

    ;; If this person does not adhere to track rules, they'll take a shortcut if the path deviates from the
    ;; 'as the crow flies' direction to destination by more than shortcut-threshold degrees
    ;; Extra condition to keep them walking through water

    ifelse not adheres? and ((abs (towards next-path - towards destination)) >= shortcut-threshold)
    [
      ;; Add +- 5 degrees because scrub bashing does not work in a straight line
      let off-path (towards destination) + random-float 10 - 5

      set heading off-path

    ]

    [set heading towards next-path]

  ]
  [set heading towards destination]

  ;; More effort to stop them walking through water
;  if patch-ahead 1 != nobody and [pcolor] of patch-ahead 1 = 95 [ ;; Go around water
;      ifelse any? patches with [pcolor != 95] in-radius 3 [
;        report towards min-one-of patches with [pcolor != 95] in-radius 3 [distance destination]
;      ]
;      [
;        report towards destination
;      ]
;  ]

  ; if there are no nearby routes to my destination
  report heading

end

to-report find-path [goal-no]
  ask neighbors with [pcolor != 95] [

    ;; Update closest distance to goal if new distance is significantly less than already recorded

    if [item goal-no dist-goals] of myself < item goal-no dist-goals - 10 [

      set dist-goals replace-item goal-no dist-goals ((item goal-no ([dist-goals] of myself)) + 1)
      ;set pcolor scale-color gray (item 11 dist-goals) 0 900

      ;; Recursively call to update this path's neighbours
      propogate-distances goal-no
    ]
  ]

end

to-report time-readable
  report (word int ((time / day-length) * 24) ":" int ((time / day-length) * 1440 mod 60))
end

to run-plots

  set-current-plot "# of tourists"
  set-current-plot-pen "tourists"
  plot count tourists

end

to-report vegetation-decile [n]

  if n = 1 [report count patches with [not path? and not lake? and vegetation-health = 0] + count patches with [not path? and not lake? and (vegetation-health / max-health) > ((n - 1) / 10) and (vegetation-health / max-health) <= (n / 10)]]
  report count patches with [not path? and not lake? and (vegetation-health / max-health) > ((n - 1) / 10) and (vegetation-health / max-health) <= (n / 10)]
end
@#$#@#$#@
GRAPHICS-WINDOW
325
19
1114
449
-1
-1
1.5
1
10
1
1
1
0
0
0
1
-260
260
-140
140
0
0
1
ticks
30.0

BUTTON
32
34
98
67
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
114
35
177
68
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
33
125
257
158
vegetation-growth-rate
vegetation-growth-rate
0
100
15.0
1
1
NIL
HORIZONTAL

SLIDER
33
168
258
201
damage-per-step
damage-per-step
0
10
0.95
0.1
1
NIL
HORIZONTAL

SLIDER
33
78
256
111
tourist-count
tourist-count
0
2000
500.0
1
1
NIL
HORIZONTAL

PLOT
32
570
233
721
# of tourists
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"tourists" 1.0 0 -7500403 true "" ""

SLIDER
32
522
252
555
test-regrowth-after
test-regrowth-after
0
100
0.0
1
1
days
HORIZONTAL

MONITOR
206
30
264
75
time
time-readable
0
1
11

SLIDER
33
211
259
244
shortcutting-tourists
shortcutting-tourists
0
100
5.0
1
1
%
HORIZONTAL

SLIDER
33
258
262
291
shortcut-threshold
shortcut-threshold
0
180
60.0
1
1
degrees
HORIZONTAL

SLIDER
34
303
262
336
deviation-chance
deviation-chance
0
10
1.5
0.1
1
%
HORIZONTAL

SLIDER
31
348
262
381
attraction-exploration-radius
attraction-exploration-radius
0
20
3.0
1
1
NIL
HORIZONTAL

SLIDER
31
390
276
423
attraction-exploration-time
attraction-exploration-time
0
60
20.0
1
1
minutes
HORIZONTAL

MONITOR
253
572
422
617
# of dead vetegation patches
count patches with [vegetation-health < 5 and not path? and not lake?]
17
1
11

MONITOR
253
625
450
670
NIL
mean [happiness] of tourists
17
1
11

MONITOR
263
695
383
740
NIL
vegetation-decile 5
17
1
11

SLIDER
30
435
250
468
tourist-view-radius
tourist-view-radius
1
50
10.0
1
1
NIL
HORIZONTAL

SLIDER
33
480
295
513
vegetation-unhappiness-threshold
vegetation-unhappiness-threshold
0
10
1.0
0.1
1
%
HORIZONTAL

MONITOR
556
614
655
659
NIL
count tourists
17
1
11

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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
NetLogo 6.2.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>repeat day-length[go]</go>
    <timeLimit steps="50"/>
    <metric>ticks</metric>
    <metric>count patches with [vegetation-health &lt; 5 and not path? and not lake?]</metric>
    <metric>happiness-avg / happiness-count</metric>
    <metric>vegetation-decile 1</metric>
    <metric>vegetation-decile 2</metric>
    <metric>vegetation-decile 3</metric>
    <metric>vegetation-decile 4</metric>
    <metric>vegetation-decile 5</metric>
    <metric>vegetation-decile 6</metric>
    <metric>vegetation-decile 7</metric>
    <metric>vegetation-decile 8</metric>
    <metric>vegetation-decile 9</metric>
    <metric>vegetation-decile 10</metric>
    <enumeratedValueSet variable="tourist-count">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shortcutting-tourists">
      <value value="10"/>
      <value value="7.5"/>
      <value value="5"/>
      <value value="2.5"/>
      <value value="1"/>
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shortcut-threshold">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="test-regrowth-after">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviation-chance">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vegetation-growth-rate">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attraction-exploration-radius">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="damage-per-step">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attraction-exploration-time">
      <value value="20"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="sc-sensitivity" repetitions="3" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>repeat day-length[go]</go>
    <timeLimit steps="50"/>
    <metric>ticks</metric>
    <metric>count patches with [vegetation-health &lt; 5 and not path? and not lake?]</metric>
    <metric>happiness-avg / happiness-count</metric>
    <metric>vegetation-decile 1</metric>
    <metric>vegetation-decile 2</metric>
    <metric>vegetation-decile 3</metric>
    <metric>vegetation-decile 4</metric>
    <metric>vegetation-decile 5</metric>
    <metric>vegetation-decile 6</metric>
    <metric>vegetation-decile 7</metric>
    <metric>vegetation-decile 8</metric>
    <metric>vegetation-decile 9</metric>
    <metric>vegetation-decile 10</metric>
    <enumeratedValueSet variable="tourist-count">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shortcutting-tourists">
      <value value="4.75"/>
      <value value="5.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shortcut-threshold">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="test-regrowth-after">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviation-chance">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vegetation-growth-rate">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attraction-exploration-radius">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="damage-per-step">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attraction-exploration-time">
      <value value="20"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="dps-sensitivity" repetitions="3" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>repeat day-length[go]</go>
    <timeLimit steps="50"/>
    <metric>ticks</metric>
    <metric>count patches with [vegetation-health &lt; 5 and not path? and not lake?]</metric>
    <metric>happiness-avg / happiness-count</metric>
    <metric>vegetation-decile 1</metric>
    <metric>vegetation-decile 2</metric>
    <metric>vegetation-decile 3</metric>
    <metric>vegetation-decile 4</metric>
    <metric>vegetation-decile 5</metric>
    <metric>vegetation-decile 6</metric>
    <metric>vegetation-decile 7</metric>
    <metric>vegetation-decile 8</metric>
    <metric>vegetation-decile 9</metric>
    <metric>vegetation-decile 10</metric>
    <enumeratedValueSet variable="tourist-count">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shortcutting-tourists">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shortcut-threshold">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="test-regrowth-after">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviation-chance">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vegetation-growth-rate">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attraction-exploration-radius">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="damage-per-step">
      <value value="0.95"/>
      <value value="1.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attraction-exploration-time">
      <value value="20"/>
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
