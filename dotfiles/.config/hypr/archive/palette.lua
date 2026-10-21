-- The archive palette (spec sections 2 and 14), as bare hex for Hyprland.
-- Keep in sync with ~/.config/quickshell/theme/Theme.qml.
return {
    day = {
        paper_base   = "c9c7c3",
        paper_card   = "d5d0ca",
        paper_raised = "ddd9d3",
        graphite     = "1e1d22",
        soft         = "3e3d42",
        faded        = "6e6c6d",
        rule_ink     = "4a4950",
        rule_faint   = "9c9995",
        accent       = "34405e",
        madder       = "7a4a46",
        shadow       = "1e1d22", shadow_active = "52", shadow_inactive = "33",   -- 32 % / 20 %
        rim_top      = "8a857e", rim_bottom      = "57524d",   -- the cut edge, focused
        rim_top_flat = "a39e97", rim_bottom_flat = "7b766f",   -- unfocused: lies flat
        dot          = "5f5b60", dot_flat        = "8a8688",   -- title-bar ink dots
        -- the three dots, colour-coded in old pigments: madder (close),
        -- yellow ochre (put away), sage green (full sheet); unfocused: dot_flat
        dot_close    = "8e5148", dot_away        = "a2834a", dot_full = "6e7b5a",
        edge_top     = "a09b94", edge_top_flat   = "b3aea7",   -- torn edge (archivebars): fainter on top
        edge_shadow  = "66",     edge_shadow_flat = "3d",      -- its shadow: 40 % / 24 %
        edge_tone    = "604c38", edge_tone_alpha  = "30",      -- the aged edge: a faint umber, 19 %
        bevel        = "ffffff", bevel_alpha     = "59",       -- light line inside the torn edge
    },
    night = {
        paper_base   = "1c2f4d",
        paper_card   = "22385a",
        paper_raised = "2a4268",
        graphite     = "e6e1d6",
        soft         = "c9ccd2",
        faded        = "8e9cb3",
        rule_ink     = "b8bfcc",
        rule_faint   = "4e6283",
        accent       = "a9c4e4",
        madder       = "d69a8e",
        shadow       = "08101e", shadow_active = "73", shadow_inactive = "40",   -- 45 % / 25 %
        rim_top      = "4e6283", rim_bottom      = "0b1424",
        rim_top_flat = "3c5274", rim_bottom_flat = "13213a",
        dot          = "8e9cb3", dot_flat        = "5f7193",
        dot_close    = "b9817a", dot_away        = "bba373", dot_full = "8d9d82",
        edge_top     = "4e6283", edge_top_flat   = "3c5274",
        edge_shadow  = "8c",     edge_shadow_flat = "4d",
        edge_tone    = "050b16", edge_tone_alpha  = "40",
        bevel        = "9fb4d6", bevel_alpha     = "26",
    },
}
