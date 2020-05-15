;;;;;;;;;;;;;;;;;;;;;;:
;; DECLARATIONS      ;;
;;;;;;;;;;;;;;;;;;;;;;:


globals [
  ; patch agentsets
  air
  ice
  water
  ground
  upper-limit
]

patches-own [ light ]

breed [ producers producer ]

breed [ grazers grazer ]

breed [ predators predator ]

turtles-own [ energy ]

producers-own [ turbulence ]

grazers-own [ contrast ]

predators-own [ head ]


;;;;;;;;;;;;;;;;;;;;;;
;; SETUP PROCEDURES ;;
;;;;;;;;;;;;;;;;;;;;;;


to setup
  clear-all
  random-seed 0
  reset-ticks
  setup-globals
  setup-environment
  setup-producers
  setup-grazers
  setup-predators
end


to setup-globals
  set air    patches with [ pycor = max-pycor ]
  set water  patches with [ abs pycor != max-pycor ]
  set ice    patches with [ pycor = max-pycor - 1 ]
  set ground patches with [ pycor = min-pycor ]
  ifelse ice-cap
    [ set upper-limit max-pycor - 2 ]
    [ set upper-limit max-pycor - 1 ]
end


to setup-environment
  ask air    [ set light 1 ]
  ask water  [ set light 0 ]
  ask ice    [ set light 0 ]
  ask ground [ set light 0 ]
  spread-light
  recolor-environment true
end


to recolor-environment [setting-up]

  ask air [
    if day-and-night [
      ifelse setting-up or daytime [
        set pcolor yellow + 4
      ] [
        set pcolor black
      ]
    ]
  ]

  ask water [
    ifelse setting-up or light > 0 [
      ; make water with more light brighter
      set pcolor sky - 4 + light * 8
    ] [
      ; make deeper water darker so things are prettier
      set pcolor max list ( sky - 3 - 0.2 * (upper-limit - pycor) ) 90
    ]
  ]

  ifelse ice-cap [
    set upper-limit max-pycor - 2
    ask ice [ set pcolor cyan + 2 ]
  ] [
    set upper-limit max-pycor - 1
  ]

  ask ground [
    set pcolor brown - 4
  ]

end


to setup-producers

  set-default-shape producers "dot"

  create-producers world-width * 3 [
    set turbulence 0.3 + random-float 0.4
    set heading 0
    set color one-of [green lime turquoise]
    set energy 1 + random 1
    ; spread the producers throughout the water patches
    setxy max-pxcor - random-float max-pxcor * 2
          upper-limit + ( random-float 2.5 - 5 )
  ]

end


to setup-grazers

  set-default-shape grazers "bug"

  create-grazers world-width [
    set heading 0
    set color sky - random-float 3
    set energy 2 + random 2
    ; spread the grazers throughout the water patches
    setxy max-pxcor - random-float max-pxcor * 2
          [pycor] of one-of water
    camouflage-grazers
  ]

end


to setup-predators

  set-default-shape predators "fish"

  create-predators 10
    [ set heading 90
      set color one-of [red magenta orange]
      set energy 6 + random 3
      ; spread the predators throughout the water patches
      setxy max-pxcor - random-float max-pxcor * 2
            upper-limit + ( random-float 2.5 - 5 )
    ]

end


;;;;;;;;;;;;;;;;;;;
;; GO PROCEDURES ;;
;;;;;;;;;;;;;;;;;;;


to go

  if not any? producers [ stop ]

  ; 24 hour days
  let day ticks / 24
  ; assume all months are the same length
  let month day / 10
  ; day length cycles up and down based on the time of year
  if change-day-length [
    set day-length precision ( 12 + 4 * sin ( month * 180 / 12 ) ) 2
  ]

  if day-and-night [
    spread-light
  ]

  ask producers [
    change-turbulence light
    grow-producers
    move-producers
    death
  ]

  ask grazers [
    grow-grazers
    move-grazers
    camouflage-grazers
    death
  ]

  ask predators [
    grow-predators
    move-predators
    death
  ]

  recolor-environment false

  ; advance tick counter without plotting
  tick-advance 1

  ; let things go a little before plotting
  if ticks mod 5 = 0 [ update-plots ]

  ; stop if too much agents
  if count turtles > 5000 [ stop ]

end


to spread-light

  ifelse daytime

    [ ask air   [ set light 1 ]
      ask water [ set light 0 ]
      ask ice   [ set light 0 ]

      ; we sort the water patches top to bottom and then ask them in turn to grab some light from above
      if not ice-cap
        [ foreach sort water
          [ ?1 -> ask ?1 [ set light light + light-spreadiness * [light] of patch-at 0 1 ] ]
        ]
    ]

    [ ask air   [ set light 0 ]
      ask water [ set light 0 ]
      ask ice   [ set light 0 ]
    ]

end


to change-turbulence [ light-present ] ; producers procedure

  ; the amount of new turbulence is random to ensure mixing within the photic layer
  if daytime and light-present > 0.01
    [ set turbulence ( random-float 0.8 ) ]

  if daytime and light-present <= 0.01
    [ set turbulence ( 0.5 + random-float 0.5 ) ]

end


to move-producers ; producers procedure

  ; move vertically according to "turbulence"
  let amount-to-move ( 1 - 2 * turbulence )
  fd amount-to-move

  ifelse ice-cap
    [ ; stick under the ice
      let icealgae producers with [ycor >= upper-limit - 0.5]
      ask icealgae [
        set ycor upper-limit + 0.5
      ]
    ]
    [ ; randomly move the producers lateraly
      rt one-of list -90 90
      let amount-to-explore random-float 0.5
      fd amount-to-explore
      set heading 0

      ; producers don't jump into the air
      set ycor min list ycor upper-limit
    ]

  ; producers die if on the bottom
  if member? patch-here ground [ die ]

end


to grow-producers ; producers procedure

  ; producers grow from energy source (light)
  let gain ( random-float 1.5 * light * exp ( -0.1 * light ) )
  let n count producers
  let limiter ( 1 - n / ( n + 100 ) )
  set energy ( energy + gain * limiter )

  if energy >= 4 [
    set energy ( energy / 2 ) ; divide energy equally between two daughter cells
    hatch 1                   ; "hatch" one daughter cell
  ]

  ; basal metabolic cost
  set energy energy * 0.99

end


to move-grazers ; grazers procedure

  ; randomly move the grazers lateraly if no ice
  let amount-to-explore random-float 0.25
  rt one-of list -90 90
  fd amount-to-explore
  set heading 0

  let amount-to-move 0

  set heading 0

  ifelse ice-cap [
    set amount-to-move 0.2 * ( 91 - pcolor )
  ] [
    ; there is a vertical gradient in color: upper is lighter, lower is darker
    ; grazers go towards the depth of equal color
    set amount-to-move 0.2 * ( color - pcolor )
  ]

  if amount-to-move > 0 [
    ; grazers don't jump into the air
    let distance-to-air (upper-limit - ycor)
    set amount-to-move min list distance-to-air amount-to-move
  ]

  if amount-to-move < 0 [
    ; grazers don't burrow into the ground
    let distance-to-ground (min-pycor + 1 - ycor)
    set amount-to-move max list distance-to-ground amount-to-move
  ]

  fd amount-to-move

  ; energy cost of moving
  set energy energy - 0.05 * ( abs amount-to-move + amount-to-explore ) ; cost of moving

  ifelse daytime [
    set hidden? false
  ] [ if not Visible [
      set hidden? true
      ]
  ]
end


to camouflage-grazers

  ; set camouflage (invisible at night)
  ifelse light > 0.01
  [ set contrast abs ( color - pcolor ) ]
  [ set contrast 0 ]

end


to grow-grazers ; grazers procedure

  let prey one-of producers-here           ; target a random producer in the same patch
  if prey != nobody [                      ; did we find one?  if so,
    if random-float 1 > 0.90 [             ; try to catch it (probability 0.1)
      set energy energy + [energy] of prey ; get energy from the prey
      ask prey [ die ]                     ; kill it
    ]
  ]

  if energy >= 10 [
    set energy ( energy / 2 ) ;; divide energy equally between parent and offspring
    hatch 1                   ;; "hatch" one offspring
  ]

end


to move-predators ; predators procedure

  ; randomly direct motion of the predators
  let amount-to-explore 0

  ifelse ice-cap
    [ set amount-to-explore random-float 0.5 ]
    [ set amount-to-explore random-float 1.5 ]
  fd amount-to-explore

  ; prevent predators to jump in the air or burrow in the ground
  set ycor min list upper-limit ycor
  set ycor max list ( min-pycor + 1 ) ycor

  if ycor >= upper-limit
    [ set heading 90 + random-float 30 ]

  if daytime and light <= 0.01
    [ set heading 90 - random-float 30 ]

  ; energy cost of moving
  set energy energy - 0.1 * abs amount-to-explore

end


to grow-predators ; predators procedure

  ; identify a random grazer in a radius of 1 patch
  let prey grazers in-radius predators-sight

  if any? prey                                         ; if there is one, then
    [ set prey max-one-of prey [contrast]              ; choose the most visible (if any)

      let crowding min list ( count grazers / 30 ) 1   ; compute a crowing index that increases detection risk

      let visibility [contrast] of prey > 1 - crowding ; check whether it is actually seen by the predator

      ifelse visibility and ( random-float 1 > 0.7 )   ; if so, try to catch it (probability 0.3)
        [ set energy energy + [energy] of prey         ; 1) get energy from the prey and
          ask prey [ die ]                             ;    kill it
          set heading 90 ]                             ; 2) keep strolling along the same depth
        [ set heading heading + random-float 10 - 20 ] ; if not, change heading to explore around
    ]

  if energy >= 20
    [
      set energy energy - 10   ; divide energy equally between paent and offspring
      hatch 2 [ set energy 5 ] ; "hatch" one offspring
    ]

end


to death ; turtle procedure
  ; if energy dips below zero, DIE
  if energy < 0 [ die ]
end


to-report daytime
  report ticks mod 24 < day-length
end

; Copyright 2017 Frederic Maps.
; See Info tab for full copyright and license.
@#$#@#$#@
GRAPHICS-WINDOW
309
10
887
649
-1
-1
30.0
1
8
1
1
1
0
1
0
1
-9
9
-10
10
1
1
1
ticks
10.0

BUTTON
10
55
74
88
NIL
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

PLOT
10
325
299
490
Criters abundance
NIL
NIL
0.0
10.0
0.0
300.0
true
true
"" ""
PENS
"Producers" 1.0 0 -10899396 true "" "plot count producers"
"Grazers" 1.0 0 -13791810 true "" "plot count grazers"
"Predators" 1.0 0 -2674135 true "" "plot count predators"

BUTTON
105
55
168
88
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
915
60
1075
93
light-spreadiness
light-spreadiness
0.5
0.85
0.6
0.05
1
NIL
HORIZONTAL

SLIDER
916
113
1076
146
day-length
day-length
6
18
15.25
0.1
1
hours
HORIZONTAL

SWITCH
10
190
170
223
change-day-length
change-day-length
0
1
-1000

SWITCH
10
145
170
178
day-and-night
day-and-night
0
1
-1000

TEXTBOX
1086
128
1196
154
light hours per 24 h
11
0.0
0

TEXTBOX
180
150
285
185
change light throughout the day
11
0.0
0

TEXTBOX
180
195
295
237
change duration of light from day to day
11
0.0
0

SWITCH
10
235
170
268
ice-cap
ice-cap
1
1
-1000

TEXTBOX
180
245
285
263
presence of ice cap
11
0.0
1

TEXTBOX
1086
68
1191
94
coefficient of light penetration
11
0.0
1

TEXTBOX
970
15
1120
40
List of parameters
16
0.0
1

TEXTBOX
60
15
135
33
Switches
16
0.0
1

PLOT
10
505
300
670
Criters energy
NIL
NIL
0.0
20.0
0.0
150.0
false
true
"" ""
PENS
"Producers" 1.0 1 -10899396 true "" "histogram [energy] of producers"
"Grazers" 1.0 1 -13791810 true "" "histogram [energy] of grazers"
"Predators" 1.0 1 -2674135 true "" "histogram [energy] of predators"

SWITCH
10
280
170
313
Visible
Visible
0
1
-1000

TEXTBOX
180
290
330
308
grazers visible
11
0.0
1

BUTTON
10
100
170
133
Add predators
setup-predators
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
915
165
1075
198
predators-sight
predators-sight
0
3
1.4
0.05
1
NIL
HORIZONTAL

TEXTBOX
1085
170
1200
200
Predators field of vision
11
0.0
1

@#$#@#$#@
## WHAT IS IT?

This is a model of a simplistic pelagic ecosystem consisting of a column of water containing phytoplankton (unicellular algae) -> mesozooplankton (tiny crustaceans) -> fish. Primary production is forced by light that is attenuated by the water column. 
Several parameters can be adjusted, and because it intends to represent processes in polar oceans, sea ice can be turned on & off.

## HOW IT WORKS

As primary producers, phytoplankton needs light in order to grow. Light is abundant in the surface waters, but is rapidly (exponentially) attenuated with depth. It also undergoes two cycles: 1) a daily cycle, and 2) a seasonal change in photoperiod. If they have enough light, they can grow and divide. However, they tend to sink, so they have to manage to divide before getting out of the well-lit zone.

As grazers, zooplankton needs to feed on phytoplankton cells. They are continuously filtering the water and are attracted in the well-lit surface layer because phytoplankton is abundant there. However, they have to trade-off their own growth with the risk of being spotted and eaten by their visual predators, the fish. As a result, they developed diel vertical migration, feeding at the surface at night and hiding in the deep during the day. In the model, zooplankton individuals do this by continuously targeting the water layer that offers the least contrast in colours (the water's and their own).

As secondary producers, fish visually hunt for zooplankton. Fish cruises randomly in the water layers that offer sufficient sight. When the contrast between the zooplankton and the water is strong enough, they can try catching it.

## HOW TO USE IT

On the LEFT side:

The SETUP button prepares the ecosystem and the GO button runs the simulation.

The DAY-AND-NIGHT switch allows for light to follow a daily cycle or to remain constant during the simulation. It can be activated at any moment. 

If the switch is "On", then the CHANGE-DAY-LENGTH switch allows to have a seasonal cycle in photoperiod (relative proportion of day and night) or to have a constant photoperiod.

The ICE-CAP switch allows to make appear (or disappear) an ice cap that prevent light to penetrate the water column. Except from the phytoplankton cells trapped within the ice layer, phytoplankton stop growing and sinks down. Eventually, if sea ice is present continuously,fish first, then zooplankton die off.

The VISIBLE switch allows to highlight the zooplankton individuals, even when they are actually hidden at depth. It is simply a visual aid.

Finally, the ADD PREDATORS button is simply there for doing experiments in varying the numbers of top rpedators in the system.

On the RIGHT side:

The LIGHT-SPREADINESS dial allows to change the coefficient of penetration of light in the water column.

The DAY-LENGTH dial allows to change the duration of day in a 24h cycle. When the DAY-AND-NIGHT switch is on, it changes automatically.

The PREDATOR-SIGHT dial allows to change the distance of visual perception of the fish.

## THINGS TO NOTICE

Notice how as the days get longer, the abundance of phytoplankton, zooplankton and fish increases. This seasonal signal is a lower frequency modulation that adds to the high frequency daily production signal clearly visible in phyroplankton.

Notice how copepods are aggregated towards their hiding depth during the day, and how individuals with the proper colour are selected by fish visual predation over time.

## THINGS TO TRY

To get time to pass faster, use the speed slider.

Turn off DAY-AND-NIGHT to see how the system react.

Turn on ICE-CAP to create an ice sheet that blocks light. Be careful! If you wait to long before setting it back to off, the system will eventually collapse.

How does changing the predators sight affect the system?


## CREDITS AND REFERENCES

This model was originately based on the Wilensky, U. (2005)  NetLogo Algae model.  http://ccl.northwestern.edu/netlogo/models/Algae.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright 2017 Frederic Maps.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact Frederic Maps at frederic.maps@bio.ulaval.ca.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

algae
true
0
Line -7500403 true 45 198 238 90

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
true
0
Polygon -1 true false 131 256 87 279 86 285 120 300 150 285 180 300 214 287 212 280 166 255
Polygon -1 true false 195 165 235 181 218 205 210 224 204 254 165 240
Polygon -1 true false 45 225 77 217 103 229 114 214 78 134 60 165
Polygon -7500403 true true 136 270 77 149 81 74 119 20 146 8 160 8 170 13 195 30 210 105 212 149 166 270
Circle -16777216 true false 106 55 30

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

orbit 1
true
0
Circle -7500403 true true 116 11 67
Circle -7500403 false true 41 41 218

orbit 2
true
0
Circle -7500403 true true 116 221 67
Circle -7500403 true true 116 11 67
Circle -7500403 false true 44 44 212

orbit 3
true
0
Circle -7500403 true true 116 11 67
Circle -7500403 true true 26 176 67
Circle -7500403 true true 206 176 67
Circle -7500403 false true 45 45 210

orbit 4
true
0
Circle -7500403 true true 116 11 67
Circle -7500403 true true 116 221 67
Circle -7500403 true true 221 116 67
Circle -7500403 false true 45 45 210
Circle -7500403 true true 11 116 67

orbit 5
true
0
Circle -7500403 true true 116 11 67
Circle -7500403 true true 13 89 67
Circle -7500403 true true 178 206 67
Circle -7500403 true true 53 204 67
Circle -7500403 true true 220 91 67
Circle -7500403 false true 45 45 210

orbit 6
true
0
Circle -7500403 true true 116 11 67
Circle -7500403 true true 26 176 67
Circle -7500403 true true 206 176 67
Circle -7500403 false true 45 45 210
Circle -7500403 true true 26 58 67
Circle -7500403 true true 206 58 67
Circle -7500403 true true 116 221 67

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

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.2
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
1
@#$#@#$#@
