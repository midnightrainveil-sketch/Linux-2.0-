#!/usr/bin/env python3
"""Turn a checkout of hyprland-plugins/hyprbars into "archivebars".

    patch.py <path to hyprbars source dir>

Changes, kept deliberately small so they survive upstream updates:
  * renamed (plugin name, config namespace plugin:archivebars:*, window rule
    effects archivebars:*, Lua table hl.plugin.archivebars) so it can never
    clash with a stock hyprbars that hyprpm may also have installed;
  * rule_color / rule_width / rule_inset: a ruled line along the bottom of
    the bar, inset from the window's edges (the reference title bar);
  * right_icon / right_icon_action / right_icon_color / right_icon_size: a
    typed glyph on the right of the bar (the reference's "-"), clickable;
  * grain_icon / grain_icon_color / grain_icon_color_off: a second glyph left
    of it that shows and flips the window's paper grain (DeckleDeco.cpp);
  * deckle / deckle_*: a torn paper edge, bevel and shadow around every
    window, laid out of repeating tiles (deckle.cpp, DeckleDeco.cpp, copied in
    from next to this script), so it fits any window size.
Every edit is anchored on upstream text; if an anchor is missing the script
stops with an error and the installer falls back to stock hyprbars.
"""
import pathlib
import shutil
import sys

src = pathlib.Path(sys.argv[1])


def edit(name, pairs, count_check=True):
    p = src / name
    s = p.read_text()
    for old, new in pairs:
        if old not in s:
            sys.exit(f"archivebars patch: anchor not found in {name}:\n{old[:200]}")
        s = s.replace(old, new)
    p.write_text(s)


def rename(name):
    p = src / name
    s = p.read_text()
    s = s.replace("plugin:hyprbars:", "plugin:archivebars:")
    s = s.replace('registerEffect("hyprbars:', 'registerEffect("archivebars:')
    s = s.replace('addLuaFunction(PHANDLE, "hyprbars"', 'addLuaFunction(PHANDLE, "archivebars"')
    s = s.replace('return {"hyprbars",', 'return {"archivebars",')
    s = s.replace('"Hyprbar"', '"Archivebar"')
    s = s.replace("[hyprbars]", "[archivebars]")
    p.write_text(s)


for f in ("main.cpp", "barDeco.cpp", "globals.hpp", "barDeco.hpp"):
    rename(f)

# ---- new config values
edit("globals.hpp", [(
    "        SP<Config::Values::CStringValue>     barTextFont, barTextAlign, barButtonsAlignment, onDoubleClick;\n",
    "        SP<Config::Values::CStringValue>     barTextFont, barTextAlign, barButtonsAlignment, onDoubleClick;\n"
    "        SP<Config::Values::CColorValue>      ruleColor, rightIconColor;\n"
    "        SP<Config::Values::CIntValue>        ruleWidth, ruleInset, rightIconSize;\n"
    "        SP<Config::Values::CStringValue>     rightIcon, rightIconCmd, grainIcon;\n"
    "        SP<Config::Values::CColorValue>      grainIconColor, grainIconColorOff;\n",
)])

edit("main.cpp", [(
    "    HyprlandAPI::addConfigValueV2(PHANDLE, g_pGlobalState->config.onDoubleClick);\n",
    "    HyprlandAPI::addConfigValueV2(PHANDLE, g_pGlobalState->config.onDoubleClick);\n"
    "\n"
    "    g_pGlobalState->config.ruleColor      = makeShared<Config::Values::CColorValue>(\"plugin:archivebars:rule_color\", \"Colour of the rule under the bar (0 = none)\", 0x00000000);\n"
    "    g_pGlobalState->config.ruleWidth      = makeShared<Config::Values::CIntValue>(\"plugin:archivebars:rule_width\", \"Thickness of the rule under the bar\", 1);\n"
    "    g_pGlobalState->config.ruleInset      = makeShared<Config::Values::CIntValue>(\"plugin:archivebars:rule_inset\", \"Inset of the rule from the window edges\", 0);\n"
    "    g_pGlobalState->config.rightIcon      = makeShared<Config::Values::CStringValue>(\"plugin:archivebars:right_icon\", \"Text glyph on the right of the bar\", \"\");\n"
    "    g_pGlobalState->config.rightIconCmd   = makeShared<Config::Values::CStringValue>(\"plugin:archivebars:right_icon_action\", \"Command run when the right glyph is clicked\", \"\");\n"
    "    g_pGlobalState->config.rightIconColor = makeShared<Config::Values::CColorValue>(\"plugin:archivebars:right_icon_color\", \"Colour of the right glyph\", 0xff000000);\n"
    "    g_pGlobalState->config.rightIconSize  = makeShared<Config::Values::CIntValue>(\"plugin:archivebars:right_icon_size\", \"Size of the right glyph\", 16);\n"
    "    HyprlandAPI::addConfigValueV2(PHANDLE, g_pGlobalState->config.ruleColor);\n"
    "    HyprlandAPI::addConfigValueV2(PHANDLE, g_pGlobalState->config.ruleWidth);\n"
    "    HyprlandAPI::addConfigValueV2(PHANDLE, g_pGlobalState->config.ruleInset);\n"
    "    HyprlandAPI::addConfigValueV2(PHANDLE, g_pGlobalState->config.rightIcon);\n"
    "    HyprlandAPI::addConfigValueV2(PHANDLE, g_pGlobalState->config.rightIconCmd);\n"
    "    HyprlandAPI::addConfigValueV2(PHANDLE, g_pGlobalState->config.rightIconColor);\n"
    "    HyprlandAPI::addConfigValueV2(PHANDLE, g_pGlobalState->config.rightIconSize);\n"
    "    g_pGlobalState->config.grainIcon         = makeShared<Config::Values::CStringValue>(\"plugin:archivebars:grain_icon\", \"Glyph that shows and flips the window's grain (empty = none)\", \"\");\n"
    "    g_pGlobalState->config.grainIconColor    = makeShared<Config::Values::CColorValue>(\"plugin:archivebars:grain_icon_color\", \"Grain glyph, grain on\", 0xff000000);\n"
    "    g_pGlobalState->config.grainIconColorOff = makeShared<Config::Values::CColorValue>(\"plugin:archivebars:grain_icon_color_off\", \"Grain glyph, grain off\", 0x66000000);\n"
    "    HyprlandAPI::addConfigValueV2(PHANDLE, g_pGlobalState->config.grainIcon);\n"
    "    HyprlandAPI::addConfigValueV2(PHANDLE, g_pGlobalState->config.grainIconColor);\n"
    "    HyprlandAPI::addConfigValueV2(PHANDLE, g_pGlobalState->config.grainIconColorOff);\n",
)])

# ---- state for the right glyph's texture
edit("barDeco.hpp", [(
    "    SP<Render::ITexture>       m_pTextTex;\n",
    "    SP<Render::ITexture>       m_pTextTex;\n"
    "    SP<Render::ITexture>       m_pRightTex;\n"
    "    std::string                m_szRightKey;\n"
    "    SP<Render::ITexture>       m_pGrainTex;\n"
    "    std::string                m_szGrainKey;\n",
)])

edit("barDeco.cpp", [
    ('#include "barDeco.hpp"\n', '#include "barDeco.hpp"\n#include "DeckleDeco.hpp"\n'),
    # the title leaves room for the right glyph
    (
        "    const int  paddingTotal      = scaledBarPadding * 2 + scaledButtonsSize + (ALIGN != \"left\" ? scaledButtonsSize : 0);\n",
        "    const int  rightGlyphRoom    = (g_pGlobalState->config.rightIcon->value().empty() ? 0 : g_pGlobalState->config.rightIconSize->value() * 2 * scale) +\n"
        "                                   (g_pGlobalState->config.grainIcon->value().empty() ? 0 : g_pGlobalState->config.rightIconSize->value() * 1.6 * scale);\n"
        "    const int  paddingTotal      = scaledBarPadding * 2 + scaledButtonsSize + (ALIGN != \"left\" ? scaledButtonsSize : 0) + rightGlyphRoom;\n",
    ),
    # a click on the right glyph runs its action
    (
        "    if (doButtonPress(BARPADDING, BARBUTTONPADDING, HEIGHT, COORDS, BUTTONSRIGHT))\n        return;\n",
        "    {\n"
        "        const auto RICON = g_pGlobalState->config.rightIcon->value();\n"
        "        const auto RCMD  = g_pGlobalState->config.rightIconCmd->value();\n"
        "        const auto RSIZE = g_pGlobalState->config.rightIconSize->value();\n"
        "        if (!RICON.empty() && !RCMD.empty() && COORDS.x >= assignedBoxGlobal().w - BARPADDING - RSIZE * 1.5) {\n"
        "            g_pKeybindManager->m_dispatchers[\"exec\"](RCMD);\n"
        "            return;\n"
        "        }\n"
        "        // the grain glyph, in the space to the left of it\n"
        "        const double GRIGHT = assignedBoxGlobal().w - BARPADDING - RSIZE * 1.5;\n"
        "        if (!g_pGlobalState->config.grainIcon->value().empty() && COORDS.x >= GRIGHT - RSIZE * 1.6 && COORDS.x < GRIGHT) {\n"
        "            deckleToggleGrain(PWINDOW);\n"
        "            damageEntire();\n"
        "            return;\n"
        "        }\n"
        "    }\n"
        "\n"
        "    if (doButtonPress(BARPADDING, BARBUTTONPADDING, HEIGHT, COORDS, BUTTONSRIGHT))\n        return;\n",
    ),
    # draw the rule and the right glyph, inside the bar's scissor
    (
        "    renderBarButtons(&textBox, pMonitor->m_scale, a);\n",
        "    {\n"
        "        const auto RULECOL = g_pGlobalState->config.ruleColor->value();\n"
        "        const auto RULEW   = g_pGlobalState->config.ruleWidth->value();\n"
        "        const auto RULEIN  = g_pGlobalState->config.ruleInset->value();\n"
        "        if (RULECOL != 0 && RULEW > 0) {\n"
        "            CHyprColor ruleColor = configColor(RULECOL);\n"
        "            ruleColor.a *= a;\n"
        "            CBox ruleBox = {textBox.x + RULEIN * pMonitor->m_scale, textBox.y + BARBUF.y - RULEW * pMonitor->m_scale, BARBUF.x - 2.0 * RULEIN * pMonitor->m_scale,\n"
        "                            RULEW * pMonitor->m_scale};\n"
        "            ruleBox.round();\n"
        "            if (ruleBox.w > 0 && ruleBox.h > 0)\n"
        "                g_pHyprOpenGL->renderRect(ruleBox, ruleColor, {.round = 0, .roundingPower = 2.F});\n"
        "        }\n"
        "\n"
        "        const auto RICON = g_pGlobalState->config.rightIcon->value();\n"
        "        if (!RICON.empty()) {\n"
        "            const auto RSIZE = g_pGlobalState->config.rightIconSize->value();\n"
        "            const auto RCOL  = g_pGlobalState->config.rightIconColor->value();\n"
        "            const auto RFONT = g_pGlobalState->config.barTextFont->value();\n"
        "            const auto RKEY  = std::string{RICON} + \"|\" + std::to_string(RSIZE) + \"|\" + std::to_string(RCOL) + \"|\" + std::to_string(pMonitor->m_scale);\n"
        "            if (!m_pRightTex || m_pRightTex->m_texID == 0 || m_szRightKey != RKEY) {\n"
        "                m_pRightTex  = g_pHyprRenderer->renderText(std::string{RICON}, configColor(RCOL), std::round(RSIZE * pMonitor->m_scale), false, std::string{RFONT});\n"
        "                m_szRightKey = RKEY;\n"
        "            }\n"
        "            if (m_pRightTex && m_pRightTex->m_texID != 0) {\n"
        "                const auto RPAD = g_pGlobalState->config.barPadding->value();\n"
        "                CBox       rbox = {textBox.x + BARBUF.x - RPAD * pMonitor->m_scale - m_pRightTex->m_size.x, textBox.y + std::round((BARBUF.y - m_pRightTex->m_size.y) / 2.0),\n"
        "                                   m_pRightTex->m_size.x, m_pRightTex->m_size.y};\n"
        "                g_pHyprOpenGL->renderTexture(m_pRightTex, rbox, {.a = a});\n"
        "            }\n"
        "        }\n"
        "\n"
        "        const auto GICON = g_pGlobalState->config.grainIcon->value();\n"
        "        if (!GICON.empty()) {\n"
        "            const bool GON   = deckleGrainOn(m_pWindow.lock());\n"
        "            const auto GSIZE = g_pGlobalState->config.rightIconSize->value();\n"
        "            const auto GCOL  = GON ? g_pGlobalState->config.grainIconColor->value() : g_pGlobalState->config.grainIconColorOff->value();\n"
        "            const auto GFONT = g_pGlobalState->config.barTextFont->value();\n"
        "            const auto GKEY  = std::string{GICON} + \"|\" + std::to_string(GSIZE) + \"|\" + std::to_string(GCOL) + \"|\" + std::to_string(pMonitor->m_scale);\n"
        "            if (!m_pGrainTex || m_pGrainTex->m_texID == 0 || m_szGrainKey != GKEY) {\n"
        "                m_pGrainTex  = g_pHyprRenderer->renderText(std::string{GICON}, configColor(GCOL), std::round(GSIZE * 0.8 * pMonitor->m_scale), false, std::string{GFONT});\n"
        "                m_szGrainKey = GKEY;\n"
        "            }\n"
        "            if (m_pGrainTex && m_pGrainTex->m_texID != 0) {\n"
        "                const auto RPAD = g_pGlobalState->config.barPadding->value();\n"
        "                const double cx = BARBUF.x - (RPAD + GSIZE * 2.3) * pMonitor->m_scale;\n"
        "                CBox         gbox = {textBox.x + std::round(cx - m_pGrainTex->m_size.x / 2.0), textBox.y + std::round((BARBUF.y - m_pGrainTex->m_size.y) / 2.0),\n"
        "                                     m_pGrainTex->m_size.x, m_pGrainTex->m_size.y};\n"
        "                g_pHyprOpenGL->renderTexture(m_pGrainTex, gbox, {.a = a});\n"
        "            }\n"
        "        }\n"
        "    }\n"
        "\n"
        "    renderBarButtons(&textBox, pMonitor->m_scale, a);\n",
    ),
    # re-render the glyph after a config reload
    (
        "    m_pTextTex           = nullptr;\n",
        "    m_pTextTex           = nullptr;\n"
        "    m_pRightTex          = nullptr;\n"
        "    m_pGrainTex          = nullptr;\n",
    ),
])

# ---- the paper edge: its own decoration, in its own files
here = pathlib.Path(__file__).resolve().parent
for f in ("deckle.hpp", "deckle.cpp", "DeckleDeco.hpp", "DeckleDeco.cpp"):
    shutil.copy(here / f, src / f)

edit("Makefile", [
    ("SRC = main.cpp barDeco.cpp BarPassElement.cpp\n", "SRC = main.cpp barDeco.cpp BarPassElement.cpp deckle.cpp DeckleDeco.cpp\n"),
    ("INCLUDES = `pkg-config --cflags ", "INCLUDES = `pkg-config --cflags cairo "),
])

edit("main.cpp", [
    ('#include "barDeco.hpp"\n', '#include "barDeco.hpp"\n#include "DeckleDeco.hpp"\n'),
    ("static void onNewWindow(PHLWINDOW window) {\n", "static void onNewWindow(PHLWINDOW window) {\n    deckleOnNewWindow(window);\n\n"),
    ("static void onUpdateWindowRules(PHLWINDOW window) {\n", "static void onUpdateWindowRules(PHLWINDOW window) {\n    deckleOnUpdateRules(window);\n\n"),
    ("    if (Config::mgr()->type() == Config::CONFIG_LEGACY)\n        HyprlandAPI::addConfigKeyword(",
     "    deckleInit(PHANDLE);\n\n    if (Config::mgr()->type() == Config::CONFIG_LEGACY)\n        HyprlandAPI::addConfigKeyword("),
    ('    g_pHyprRenderer->m_renderPass.removeAllOfType("CBarPassElement");\n',
     '    g_pHyprRenderer->m_renderPass.removeAllOfType("CBarPassElement");\n    deckleExit();\n'),
])

print("archivebars: patched", src)
