---
title: 'The oranges that looked muddy had a higher G/R ratio'
description: 'While redoing the colors of the timeline blocks, I rejected one orange after another as dirty. Lining up the RGB values of the candidates, the ones that looked muddy to me had a higher G/R ratio, so I made G/R and R part of my checks. Also why black text on a light fill made the block look brown to me.'
lang: en
translationKey: orange-muddy-g-r-ratio
publishDate: 2026-10-01
tags: ['Design', 'Color', 'macOS']
draft: false
---

I build [FirnPlanner](https://firnplanner.l4l4.dev/), a daily planner for macOS, as a personal project. I recently redid the colors of its timeline, aiming to fill schedule blocks with a bright orange.

For a while I kept proposing orange candidates and rejecting them as "dirty" or "rotten". I could not tell what to fix, so I was just moving the color around. In the end I went looking for the cause. What follows is a record of how these colors looked to me, not a general rule.

## The candidates that looked muddy had a higher G/R

At first I assumed a bluish tint was making it muddy. When I lined up the candidates' RGB values, the ones that looked muddy to me were the ones with a higher ratio of G to R (G/R).

<div style="display:flex;flex-wrap:wrap;gap:8px;margin:1em 0;">
<span style="background:#E8A33D;color:#3D2000;padding:10px 14px;border-radius:4px;">#E8A33D (G/R 0.70)</span>
<span style="background:#D9A441;color:#3D2000;padding:10px 14px;border-radius:4px;">#D9A441 (G/R 0.76)</span>
<span style="background:#FFC14D;color:#3D2000;padding:10px 14px;border-radius:4px;">#FFC14D (G/R 0.76)</span>
</div>

These values are computed from the hex codes.

| Color | R | G | B | G/R |
|---|---|---|---|---|
| `#E8A33D` | 232 | 163 | 61 | 0.70 |
| `#D9A441` | 217 | 164 | 65 | 0.76 |
| `#FFC14D` | 255 | 193 | 77 | 0.76 |

To my eye, `#E8A33D` looked like a normal orange and `#D9A441` looked rotten. The two colors differ in all of R, G and B, so this comparison alone does not show that G/R is the cause. Among the differences, the one I focused on was G/R: 0.70 versus 0.76. The idea that a color drifts toward yellow-green as G gets closer to R fits what I saw. Since then, I treat a candidate with G/R above 0.75 as one to suspect of muddiness.

### Making it lighter, or mixing in white, does not remove it

Brightening the color to get rid of the muddiness did not help. Mixing in white pushes both R and G toward 255, so G/R moves toward 1. Mixing 50% white into `#D9A441` gives `#ECD2A0`, and its G/R is 0.89. To me that was a color that was pale and still dirty.

### With about the same G/R, the color with R at 255 did not look muddy

The color I finally adopted is `#FFC14D`. Its G/R is 0.76, the same as `#D9A441`, yet it did not look muddy. R is pinned at 255, and the whole color is lighter. This comparison can't tell which of those mattered, but I decided not to judge by G/R alone and to look at R as well.

## Black text on a light fill makes the block look brown

Once the fill was settled, the text color was the next problem. With pure black text on `#FFC14D`, the whole block looked brownish.

<div style="display:flex;flex-wrap:wrap;gap:8px;margin:1em 0;">
<span style="background:#FFC14D;color:#000000;padding:10px 14px;border-radius:4px;">9:00 Read the docs (black #000000)</span>
<span style="background:#FFC14D;color:#3D2000;padding:10px 14px;border-radius:4px;">9:00 Read the docs (dark brown #3D2000)</span>
</div>

Text covers little area, but it is dark and catches the eye, so I think it pulls the impression of the whole block. With the text set to dark brown `#3D2000`, the same fill still read as orange.

By the WCAG contrast formula, black is 12.99:1 and dark brown is 9.24:1. Black has the higher contrast, so looking brown was a separate problem from legibility.

From this I adopted a rule: move the text color toward the hue of the fill, and do not put black or the body text color on it as is.

## The current-time line is not a part of the block

There is one more color rule. I first drew the current-time line in the theme's accent orange. It blended into the block fills and became invisible. When I made the line blue, so that only the clock had its own color family, it became visible.

Later I tried using the same blue for the left band of an in-progress task, and I rejected it. The current-time line is valuable because it is the only thing with that color. Using it on parts of a block weakens that meaning. I made the band a color that moves the block's text color toward the fill.

## If it looks dirty, measure G/R and R first

Comparing candidates by eye alone, I could not tell what to change. Now, when an orange or yellow candidate looks muddy, I first compute G/R and R from the hex value, and check whether G/R is above 0.75 and whether R is maxed out. For text, I try a dark color close to the fill's hue before putting black on it.

All of these numbers come from my own eyes and my own display. I use them as a checklist when choosing colors, not as a general rule.
