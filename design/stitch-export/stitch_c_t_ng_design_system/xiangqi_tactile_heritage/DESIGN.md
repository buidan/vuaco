---
name: Xiangqi Tactile Heritage
colors:
  surface: '#210f07'
  surface-dim: '#210f07'
  surface-bright: '#4c342a'
  surface-container-lowest: '#1b0904'
  surface-container-low: '#2a170f'
  surface-container: '#2f1a12'
  surface-container-high: '#3b251c'
  surface-container-highest: '#472f26'
  on-surface: '#ffdbce'
  on-surface-variant: '#dfbfbb'
  inverse-surface: '#ffdbce'
  inverse-on-surface: '#422b22'
  outline: '#a78a86'
  outline-variant: '#58413e'
  surface-tint: '#ffb4aa'
  primary: '#ffb4aa'
  on-primary: '#680204'
  primary-container: '#a8342a'
  on-primary-container: '#ffcac3'
  inverse-primary: '#aa352b'
  secondary: '#ebc166'
  on-secondary: '#402d00'
  secondary-container: '#765700'
  on-secondary-container: '#facf73'
  tertiary: '#a2d1b5'
  on-tertiary: '#073824'
  tertiary-container: '#3a664f'
  on-tertiary-container: '#b2e2c5'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffdad5'
  primary-fixed-dim: '#ffb4aa'
  on-primary-fixed: '#410001'
  on-primary-fixed-variant: '#891d17'
  secondary-fixed: '#ffdf9e'
  secondary-fixed-dim: '#ebc166'
  on-secondary-fixed: '#261a00'
  on-secondary-fixed-variant: '#5b4300'
  tertiary-fixed: '#bdeed0'
  tertiary-fixed-dim: '#a2d1b5'
  on-tertiary-fixed: '#002113'
  on-tertiary-fixed-variant: '#234f3a'
  background: '#210f07'
  on-background: '#ffdbce'
  surface-variant: '#472f26'
typography:
  display-lg:
    fontFamily: Noto Serif
    fontSize: 36px
    fontWeight: '600'
    lineHeight: 44px
    letterSpacing: -0.02em
  display-lg-mobile:
    fontFamily: Noto Serif
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
    letterSpacing: -0.01em
  headline-lg:
    fontFamily: Noto Serif
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Noto Serif
    fontSize: 20px
    fontWeight: '500'
    lineHeight: 28px
  headline-sm:
    fontFamily: Noto Serif
    fontSize: 18px
    fontWeight: '500'
    lineHeight: 24px
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  label-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.02em
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.04em
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 10px
    fontWeight: '700'
    lineHeight: 14px
    letterSpacing: 0.06em
  stats-number:
    fontFamily: Plus Jakarta Sans
    fontSize: 20px
    fontWeight: '700'
    lineHeight: 24px
    letterSpacing: 0.02em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-sm: 0.5rem
  margin: 1rem
  margin-lg: 1.5rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
  space-2xl: 3rem
---

## Brand & Style

This design system expresses the intellectual heritage and tactile weight of traditional Asian strategy games. Anchored in the artisanal materials of heirloom Xiangqi sets—deep polished mahogany, warm walnut, weathered rice paper, cinnabar lacquer, and beaten imperial gold—the interface evokes quiet luxury, scholarly focus, and grounded physical permanence. 

The design combines tactile and modern digital sensibilities. While avoiding overt skeuomorphic clutter, it embraces physical materiality through delicate hairline borders, subtle carved insets, warm ambient shadows, and rich organic surfaces. The emotional tone is deliberate, calm, and prestigious, delivering an uncluttered, high-legibility mobile experience fit for grandmasters and modern enthusiasts alike.

## Colors

The palette draws directly from classical lacquerware, carved wooden boards, and precious minerals:

- **Primary (`#A8342A` - Traditional Crimson):** The signature cinnabar lacquer accent used for high-impact actions, Red player pieces, critical states, and primary focal points.
- **Secondary (`#C9A24B` - Imperial Gold):** Used for fine hairline framing, win/rank indicators, badge highlights, and elevated active states.
- **Tertiary (`#2E5A44` - Imperial Jade):** Used for Black player counters, success confirmations, peaceful utility states, and tactical confirmations.
- **Neutral Core (`#2C1810` - Deep Mahogany):** The foundational dark canvas. Sub-surfaces scale upward into Warm Walnut (`#4A2E1B`) and Burnt Umber (`#3A2114`) for container depth.
- **Surface Accent (`#F4E8C1` - Aged Parchment):** Used for high-contrast card surfaces, move history strips, Xiangqi wooden disc tops, and light piece bases.

Text colors strictly adhere to readability: Primary Text sits at `#F4E8C1` (Aged Parchment) over dark containers, Secondary Text at `rgba(244, 232, 193, 0.72)`, and Muted Text at `rgba(244, 232, 193, 0.44)`. On parchment surfaces, text flips to `#2C1810`.

## Typography

The typographical voice balances ceremonial tradition with quick mobile scanning:

- **Headlines & Ceremony (Noto Serif):** Brings calligraphic elegance and stately presence to modal titles, game conclusions, rank banners, and chapter headers. 
- **Application UI & Flow (Plus Jakarta Sans):** Provides geometric clarity, soft modern curves, and effortless legibility in dense gameplay telemetry, player clocks, notation sheets, and navigation elements.
- **Numbers & Clocks:** Tabular digits (`tnum`) must be enforced for game timers, move counters, and win-rate statistics to eliminate horizontal jitter during play.

## Layout & Spacing

The layout model prioritizes single-handed mobile thumb access and uncompromising board clarity:

- **Board Sandbox:** The game canvas maintains an edge-to-edge aspect ratio calibrated for the traditional 9x10 Xiangqi grid, surrounded by a mandatory `space-sm` boundary zone that prevents accidental edge-swipes.
- **HUD & Player Strips:** Symmetrical top and bottom HUD panels conform to safe areas with `margin` side padding, grouping avatar, timer, and captured pieces into modular clusters.
- **Vertical Rhythm:** Content sheets and lists use `space-md` gaps. Touch targets adhere strictly to a minimum 48×48px boundary, ensuring piece movement and button activation remain flawless under rapid time-control conditions.

## Elevation & Depth

Visual depth is achieved through physical material stacking rather than generic grey drop shadows:

- **Level 0 (Canvas Base):** Deep Mahogany (`#2C1810`) with an ultra-subtle warm vignette.
- **Level 1 (Sub-Boards & Containers):** Warm Walnut (`#4A2E1B`) inset with a top 1px hairline border at `rgba(201, 162, 75, 0.15)` (Imperial Gold) and a soft ambient drop shadow: `0 4px 16px rgba(12, 6, 4, 0.6)`.
- **Level 2 (Tactile Cards & Trays):** Aged Parchment (`#F4E8C1`) or layered Walnut panels framed with a 1px solid border at `rgba(201, 162, 75, 0.35)`. Shadow: `0 8px 24px rgba(10, 4, 2, 0.75)`.
- **Level 3 (Interactive Pieces & Modals):** Tactile carved tokens featuring dual inner highlights: a top-left rim `rgba(244, 232, 193, 0.4)` and a bottom-right bevel depression `rgba(0, 0, 0, 0.6)`, casting a crisp physical contact shadow: `0 4px 8px rgba(0, 0, 0, 0.5)`.

## Shapes

The design system employs a refined radius scale (`roundedness: 2`) that evokes hand-sanded timber edges:

- **Standard Elements (Cards, Panels, Inputs):** 0.5rem (8px) radius creates an intentional, hand-carved joinery feel.
- **Surface Groupings & Modals:** 1rem (16px) radius (`rounded-lg`) softens large overlay sheets.
- **Xiangqi Pieces:** Strictly circular (9999px / 50% radius) reflecting traditional turned-wood game tokens.
- **Interactive Action Buttons (Pills):** Fully rounded pill geometry with subtle beveling for prominent calls to action.

## Components

### Buttons
- **Primary Action (Cinnabar):** Deep Crimson (`#A8342A`) background with a soft internal top highlight, 1px Imperial Gold rim (`#C9A24B`), and Aged Parchment typography. Pressed state deepens the crimson and lowers Y-offset by 1px to mimic a physical depression.
- **Secondary Action (Timber/Gold):** Warm Walnut background, 1px Imperial Gold border, text colored `#F4E8C1`.
- **Ghost/Tertiary:** No background, hairline parchment border at 30% opacity, gold text on hover/press.

### Cards & Trays
- **Parchment Variant:** Aged Parchment (`#F4E8C1`) background, Deep Mahogany text, 1px gold frame with 20% opacity. Used for move records, victory digests, and high-readability scrolls.
- **Wood Grain Variant:** Warm Walnut (`#4A2E1B`) background, subtle inner shadow simulating an indented tray, housing player stats, captured pieces, and settings groups.

### Inputs & Selectors
- Recessed troughs with a dark umber fill (`#1E100B`), a 1px border at `rgba(201, 162, 75, 0.25)`, transitioning to solid Imperial Gold upon focus. Text renders in Aged Parchment.

### Chips & Badges
- Compact pill silhouettes with a 1px border. Ranks and win streaks feature Gold foil fills with dark wood typography; status indicators (online, spectator counts) use Jade Green tinting (`#2E5A44`).

### Game Board & Pieces
- **The Board:** Warm beech/walnut surface with carved dark cinnabar and gold lines. The River (楚河 漢界) features delicate centered calligraphy at 35% opacity.
- **Pieces:** Circular dual-ring carved wooden discs with engraved Chinese characters (traditional script). Red pieces use Crimson glyphs with gold rim bevels; Black pieces feature Jade-tinted black lacquer glyphs with silver-bronze rim bevels. Selected pieces lift vertically with an expanded warm shadow and an Imperial Gold pulsing halo.