;; Computational Modelling and Simulation Project
;; Ivy Brain (1084265) and Lily Felstead (1292118)
;; Oct 2022

breed [ attractions attraction ]
breed [ tourists tourist ]
breed [ entrances entry ]
globals [ patch-data path-file elevation-data elevation-file time day-length current-tourists happiness-avg happiness-count]
patches-own [ path? vegetation-health lake? elevation trampled? max-health dist-goals dead?]
tourists-own [ goal adheres? path-plan deviation-pos return-pos exploration-start happiness]

to setup
  clear-all
  ;; read in files created using GPS data
  set path-file "alltracks.txt"
  set elevation-file "elevation.txt"

  ;; set turtle shapes
  set-default-shape attractions "flag"
  set-default-shape tourists "person"
  set-default-shape entrances "square"

  ask patches [ set pcolor green ]

  ; construct environment
  load-patch-data
  set-patch-elevation
  place-attractions

  calculate-path-distances

  ; initialise reporting values
  set time 0
  set happiness-avg 0
  set happiness-count 1

  ;; one square is 11 metres - walk at ~4kmh = ~1ms-1 - square every ~12 seconds (because that's neater)
  set day-length 24 * 60 * 5 ;;One tick = 12 seconds

  reset-ticks
end

to go

  ;; Actions at the end of the day
  if time >= day-length or (test-regrowth-after > 0 and ticks > test-regrowth-after) [
    set time 0

    ;; Remove any remaining tourists
    ask tourists [tourist-remove]

    set current-tourists 0

    tick

    ;; Regrow vegetation and recolour the map accordingly
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
  ; read file containing coordinates and corresponding elevation
  ifelse ( file-exists? elevation-file )
  [
    set elevation-data []
    file-open elevation-file
    while [ not file-at-end? ]
    [
      set elevation-data sentence elevation-data (list (list file-read file-read file-read))
    ]
    file-close
    ; set default value
    ask patches [set elevation 900]
    ; for each set of three (x, y, elevation) get corresponding patch and assign elevation value
    foreach elevation-data [ three-tuple -> ask patch first three-tuple item 1 three-tuple [
      set elevation last three-tuple
      ; set neighbours to same elevation
      ask patches in-radius 20 [set elevation last three-tuple]
    ] ]
    ;; diffuse elevation scores so that there is a smooth transition between neighbouring values
    repeat 20 [ diffuse elevation 1 ]
    ;; if patches are not track or lake
    ask patches [if pcolor != 95 and pcolor != 5  [
      ; set max-health to be out of 100 and inverse to elevation
      set max-health round ((2000 - elevation) / 1200 * 100)
      ; colour patches depending on their elevation
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
  ; read file containing coordinates and corresponding color for tracks and lakes
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
    ; for each set of three (x, y, color) get corresponding patch and assign color
    foreach patch-data [ three-tuple -> ask patch first three-tuple item 1 three-tuple [ set pcolor last three-tuple ] ]
    ; if color = 5 (gray) set path true
    ask patches [ifelse pcolor = 5 [set path? true] [set path? false]]
    ; if color = 95 (blue) set lake true
    ask patches [ifelse pcolor = 95 [set lake? true] [set lake? false]]
    ; initialise patch variables
    ask patches [set trampled? false set dead? false]
    ; for each patch calculate the distance to each of the 10 attractions
    ask patches [set dist-goals [100000 100000 100000 100000 100000 100000 100000 100000 100000 100000 100000 100000]]
    display
  ]
  [ user-message "Cannot find path file in current directory!" ]
end

to place-attractions
  ; places flag corresponding to real-life attraction at set x y coordinates
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

  ;; For each possible goal
  ask (turtle-set attractions entrances) [
    let goal-no who
    ;; Get its immediately surrounding patches to record the distance to the goal, and propogate that to their neighbours
    ask patches in-radius 5 with [path?] [
      set dist-goals replace-item goal-no dist-goals distance myself
      propogate-distances goal-no
    ]

  ]

end

;; Propogate distance to a goal to neighbouring path segments
to propogate-distances [goal-no]

  ask neighbors with [path?] [

    ;; Update closest distance to goal if new distance is significantly less than already recorded

    if [item goal-no dist-goals] of myself <= item goal-no dist-goals - 2 [

      set dist-goals replace-item goal-no dist-goals ((item goal-no ([dist-goals] of myself)) + 1)
      ;set pcolor scale-color gray (item 11 dist-goals) 0 900

      ;; Recursively call to update this path's neighbours
      propogate-distances goal-no
    ]
  ]

end

;; Generate tourists according to the visitor arrival submodel
to gen-tourists


  ;; Arrivals start 7am, peak 11am, end 3pm
  let hour (time / day-length) * 24

  ;; Absolute linear equation that dictates arrivals
  let tourists-this-tick (tourist-count / (day-length / 3)) * 2 * ((- abs ((hour - 11) / 4)) + 1)


  if tourists-this-tick > 0 [

    ;; tourists-this-tick is often fractional, so store the cumulative output, then make sure that number of tourists exist in the system
    set current-tourists current-tourists + tourists-this-tick
    let num-to-gen int (current-tourists - count tourists)

    ;; Dove lake carpark more popular - gets 80% of arrivals, ronny creek gets 20%
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

;; Initialises the variables for each tourist
to tourist-init
  set goal one-of attractions
  set size 2
  set color yellow

  ;; If not adheres, then this tourist will take shortcuts off the track
  set adheres? random-float 100 > shortcutting-tourists

  if not adheres? [set color pink]

  ;; Position to go to when deviating from path, and position to return to
  set deviation-pos nobody
  set return-pos patch-here

  set happiness 100

  ;; Tracks how long a tourist has been exploring an attraction
  set exploration-start -1000

end

;; When a tourist is removed, add their happiness to the daily average
to tourist-remove
  set happiness-avg happiness-avg + happiness
  set happiness-count happiness-count + 1
  die
end

to vetegation-growth
  ; patches that have not been trampled in the last day may regrow
  ask patches with [not trampled?] [
    ;Only regrow if not dead, or has healthy neighbours
    if not dead? or any? neighbors with [vegetation-health > 0.6 * max-health] [

      ;; Health gain is a parmeter percentage of the healthiest neighbour's health
      set vegetation-health min list (vegetation-health + ([vegetation-health] of max-one-of neighbors [vegetation-health] * vegetation-growth-rate / 100)) max-health

      ;; Un-die if health is raised above threshold
      if vegetation-health >= 5
      [ set dead? false ]
    ]
  ]

end

to vegetation-trampled
  ; decrease vegetation health by damage-per-step value
  set trampled? true
  if vegetation-health > 0 [set vegetation-health max list (vegetation-health - damage-per-step) 0]
end

to recolor-patches
  ;; set patch color as a mix of red and green depending on elevation and health
  ask patches with [ not path? and not lake?] [
    let green-val (elevation - 600) / 1104 * 255
    let red-val (max-health - vegetation-health) / 100 * 255

    set pcolor (list red-val green-val 0)

    if vegetation-health < 5 [set dead? true]


   ]
end


to move-tourists
  ask tourists [

    ;; Actions if the tourist is at their goal (an attraction or a carpark at the end of the day)
    ;; Force the tourist to turn back towards carpark if time is later than 6pm (18)
    if any? (patch-set [patch-here] of goal) in-radius 5 or ((time / day-length) * 24 > 18 and not member? goal entrances) [

      ;; Start tracking the time they stay at this attraction, default 20m
      set exploration-start time

      ;; If they're back at the carpark, remove them
      if member? goal entrances [
        tourist-remove
      ]

      ;; Go back to carpark after 4pm
      ifelse (time / day-length) * 24 > 16 [
        set goal min-one-of entrances [distance myself]
      ] [
      ;; Otherwise pick a new attraction to go towards
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

  ;; If the tourist is exploring an attraction, set a deviation position within the exploration radius

  if deviation-pos = nobody and time - exploration-start < (attraction-exploration-time * 5) [
    set return-pos patch-here
    set deviation-pos one-of patches in-radius attraction-exploration-radius with [pcolor != 95]
  ]

  ;; Tourists set a nearby deviation point with deviation-chance

  if deviation-pos = nobody and random-float 100 < deviation-chance and [path?] of patch-here [
    set return-pos patch-here
    set deviation-pos one-of patches in-radius 3 with [pcolor != 95]

  ]

  ;; If there is a deviation position set, move towards it
  ifelse deviation-pos != nobody [
    face deviation-pos
    fd 1

    ;; If the tourist has reached the deviation position, set it to the return position, so next step they'll walk back
    ;; If deviation and return are the same, then they've finished the deviation so clear it
    if patch-here = deviation-pos [

      ifelse deviation-pos = return-pos [

        set deviation-pos nobody
      ]
      [
        set deviation-pos return-pos
      ]
    ]

  ] [

    ;; Run pathfinding to tell which way to face, then move forward
    set heading best-way-to goal
    fd 1
  ]
end

to-report best-way-to [ destination ]


  ;; Find the agent number of the destination

  let goal-no ([who] of destination)

  ;; Only goals 0 through 11 exist and have recorded paths. Head in a straight line as a failsafe
  if goal-no > 11 [report towards destination]

  ;; If there is a nearby path patch with a lower distance to my destination, select it
  let visible-patches patches in-radius 3
  let visible-routes visible-patches with [ path? ]

  let routes-that-take-me-closer visible-routes with [
    ;; dist-goals is a list belonging to each path patch, with each item storing the distance along that path to the corrensponding goal

    ;; select the paths with lower distance to this tourist's particular goal
    item goal-no dist-goals < [ item goal-no dist-goals - 1] of [patch-here] of myself
  ]

  ifelse any? routes-that-take-me-closer [
    ; from those route patches, choose the one that is the closest to me

    let next-path min-one-of routes-that-take-me-closer [ distance self ]

    ;; If this person does not adhere to track rules, they'll take a shortcut if the path deviates from the
    ;; 'as the crow flies' direction to destination by more than shortcut-threshold degrees


    ifelse not adheres? and ((abs (towards next-path - towards destination)) >= shortcut-threshold)
    [
      ;; Add +- 5 degrees because scrub bashing does not work in a straight line
      let off-path (towards destination) + random-float 10 - 5

      set heading off-path

    ]

    ;; If they're a good person, they'll go to the next path segment
    [set heading towards next-path]

  ]

  ;; If there are no paths in the vincinity, just walk straight towards destination
  [set heading towards destination]

  report heading

end

;; Old attempt to implement A* in Netlogo to avoid lakes - was quite doomed

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
1.0
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
1000
100.0
1
1
NIL
HORIZONTAL

PLOT
324
460
525
611
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
537
463
708
508
# of dead vetegation patches
count patches with [vegetation-health < 5 and not path? and not lake?]
17
1
11

MONITOR
537
514
708
559
NIL
mean [happiness] of tourists
17
1
11

MONITOR
540
567
707
612
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

@#$#@#$#@
##   Purpose
To examine how various interventions applied to Cradle Mountain visitation affect the damage visitors cause to the environment.

##   Entities, State Variables, Scale
Tourists - individuals / groups who want to visit the park. Tourists will arrive according to the visitors submodel, and stay for a random 1-5 days. There are several ‘attractions’ (walks or scenic views) they wish to visit, which may contribute to their happiness with their visit. They also cause damage to the surrounding environment, depending on their movement behaviour. People have happiness which increases when they complete walks or see scenic views at the park.

Environment - A rough topographical model of the Cradle Mountain area. GPS data was obtained from AllTrails, a database for trail maps commonly used by hikers. The GPS coordinates and elevation data were combined to generate the landscape. This area covers roughly 5.8km. The spatial scale used was 1 cell = 11 square metres. 

Vegetation - inhabits each cell, and has a given resilience to trampling based on elevation and corresponding health as it is trampled. Resilience determined by vegetation submodel. 

Tracks - built paths for people to walk on. The geographical layout of the three most popular tracks, Dove Lake Circuit, the Overland Track and Cradle Mountain Peak was calculated using the GPS data. Walking on these tracks causes no damage to the surrounding environment, unless people stray from the track.

Scenic viewpoints - Nine destinations along the tracks which include cradle mountain peak, marions lookout, lake lilla, and hansons peak provide a scenic view and thus increase tourists satisfaction. Tourists will walk towards these locations and will stay at these locations for 20 minutes. These points have the potential to become overcrowded, increasing environmental damage as people expand beyond the designated area, and decreasing satisfaction with the area.

Temporal scale - Assuming a walking speed of 1 m/s, it will take a person 3 seconds to traverse a cell. As we want to model vegetation damage to each cell, the temporal resolution will be 3 seconds. If this is computationally infeasible, the temporal scale could be simplified, with larger movements corresponding to an average damage across cells.

##   Process overview and scheduling
Firstly, people move according to the movement submodel. The environment people walk on then becomes damaged according to its type and hardiness. If people complete a walk or arrive at a certain scenic attraction, their happiness increases. They will then select another walk or attraction to visit. If a day is completed, some visitors will leave if their stay period is over, and new ones will arrive according to the visitation submodel.

##   Design Concepts
The principles addressed by this model are the human desire to visit popular scenic locations, and human-caused damage to those locations. Humans walk through the park to visit locations, largely along marked paths but with some deviations. They cause damage to the locations they walk through based on the presence of paths, and their collective numbers. This allows an examination of the collective effect of visitation on the environment.

Environmental protection is desired for the conservation of native species, but also to preserve the scenic beauty of the park; if it becomes too damaged by human activity, it will no longer be a desirable, pristine piece of nature.

People visit parks such as Cradle Mountain to have positive, new, experiences. It can be seen as an altruistic goal to allow as many people as possible to have this unique experience. It can also have a positive effect on the state economy - even if the park itself is not aggressively monetised, it still draws many visitors to the state, which benefits the wider tourism industry. The park currently has limited commercial operations, and thus this model will not examine commercial implications. However, high visitation is still assumed to be positive. It is also evident that if environmental mitigations applied to visitors become too invasive, the environment is too degraded, or the location is too overcrowded, their satisfaction with their visit will decrease. Restrictions on visitor numbers could protect the environment and increase the satisfaction of individual visitors, but still disappoint the general populace. Thus a useful parameter is ‘person-satisfaction’, taken as the multiplication of number of visitors and satisfaction score. Optimising this will encourage as many visitors as possible without devaluing their experience too much, and with minimal impact on the environment. The details of this metric will be explored further in the implementation of the model.

##   Initialisation
The model will be initialised based on data and estimations about the Cradle Mountain national park. 210k people visit per year, for an average of 575 arrivals per day, with an average stay of 2 days. The environment will be initialised with a topographic map of the area. The location of tracks and lakes and area’s elevation were initialised using GPS data. Scenic viewpoints were based on markings on tourist maps. Vegetation was initialised with the vegetation submodel, except for where tracks are marked.

##   Submodels
Fauna trampling damage / regeneration
Different fauna exist in different parts of the park, particularly dependent on elevation. These types have different tolerance to trampling, both in terms of hardiness and regrowth potential [1]. To simplify this elevation was used as a proxy for human traffic capacity. Elevation from samples of the surrounding area was obtained from AllTrails to determine the elevation in these key points. These values were then diffused to cover all patches in between to give a rough approximation of the landscape. Elevation within this area ranges from 800-1500. Higher elevation is negatively correlated with vegetation hardiness calculated as follows: maximum health = (2000 - elevation) / 1200 * 100. This gives scores between 41 for the highest points and 100 for the lowest points. Each time a patch is stepped on its health decreases by one. At the end of each day, patches that were not trampled increase their health by 15%. If the vegetation’s health drops below 5 it is considered dead and then requires at least one healthy neighbour to regrow. The growth and damage numbers were chosen as an approximation of vegetation behaviour. 

Human movement - The environmental damage caused to the park depends significantly on human movement, and modelling this movement requires several assumptions. It is assumed people largely follow walking tracks to visit certain scenic views. It is also assumed people will sometimes stray from the track, to explore or take photographs. Random deviations from the track will thus be modelled where a person will choose a random target within 30m of the track, then walk there and back, causing vegetation damage in the process.

Visitor arrival - In the initial model, visitor numbers will be held constant, and the effects of their movement on the environment will be examined. Reductions on arrivals can then be imposed as a possible intervention to examine the environmental impact. Potential extensions can use visitor satisfaction as a metric which affects desire to visit the park and thus future visitor numbers.
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
  <experiment name="experiment" repetitions="3" sequentialRunOrder="false" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>repeat day-length[go]</go>
    <timeLimit steps="100"/>
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
      <value value="100"/>
      <value value="300"/>
      <value value="500"/>
      <value value="700"/>
      <value value="900"/>
      <value value="1500"/>
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
      <value value="1"/>
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
