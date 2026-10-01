---
title: 'Orange looked muddy because of its green ratio, not its blue'
description: 'While redoing the colors of the timeline blocks, I rejected one orange after another as dirty. The cause was the G/R ratio. Notes on why adding white does not help, and why black text on a light fill makes the block look brown.'
lang: en
translationKey: orange-gets-muddy-by-green
publishDate: 2026-10-01
tags: ['Design', 'Color', 'macOS']
draft: false
---

I build [FirnPlanner](https://github.com/l4l4dev/FirnPlanner), a daily planner for macOS, as a personal project. I recently redid the colors of its timeline, aiming to fill schedule blocks with a bright orange.

For a while I kept proposing orange candidates and rejecting them as "dirty" or "rotten". I could not tell what to fix, so I was just moving the color around. In the end I went looking for the cause. What follows is a record of how these colors looked to me, not a general rule.

## Orange looked muddy when G got close to R

At first I assumed a bluish tint was making it muddy. Once I lined up the numbers, what mattered was the ratio of G to R (G/R).

<div style="display:flex;flex-wrap:wrap;gap:8px;margin:1em 0;">
<span style="background:#E8A33D;color:#3D2000;padding:10px 14px;border-radius:4px;">#E8A33D (G/R 0.70)</span>
<span style="background:#D9A441;color:#3D2000;padding:10px 14px;border-radius:4px;">#D9A441 (G/R 0.76)</span>
<span style="background:#FFC14D;color:#3D2000;padding:10px 14px;border-radius:4px;">#FFC14D (G/R 0.76)</span>
</div>

These values are computed from the hex codes.

| Color | R | G | G/R |
|---|---|---|---|
| `#E8A33D` | 232 | 163 | 0.70 |
| `#D9A441` | 217 | 164 | 0.76 |
| `#FFC14D` | 255 | 193 | 0.76 |

To my eye, `#E8A33D` looked like a normal orange and `#D9A441` looked rotten. The only difference between them is 0.70 versus 0.76. When G gets slightly closer to R, the color drifts toward yellow-green and looks muddy. As a rule of thumb, I started to feel the muddiness once G/R went above about 0.75.

### Making it lighter, or mixing in white, does not remove it

Brightening the color to get rid of the muddiness did not help. Mixing in white pushes both R and G toward 255, so G/R moves toward 1. Mixing 50% white into `#D9A441` gives `#ECD2A0`, and its G/R is 0.89. To me that was a color that was pale and still dirty.

### With the same G/R, a maxed-out R pulls it toward yellow

The color I finally adopted is `#FFC14D`, with a G/R of 0.76. That is the same level as `#D9A441`, yet it did not look muddy. R is pinned at 255, and the color reads as yellow rather than yellow-green. I had to look at the absolute value of R as well as the ratio.

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
