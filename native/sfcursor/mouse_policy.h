#pragma once

// Pure routing policy for mouse clicks that land on a SolarFlare (ImGui) window. No Win32, no game objects.
// A press the UI wants is kept from the game and handed to ImGui; its release follows it. A press that started
// in the game is never taken over, so dragging out of a game control onto a window cannot strand a button.
struct MouseGuardPolicy {
    enum Action { Pass, SwallowDown, SwallowUp, SwallowWheel };
    static constexpr int BUTTONS = 3; // left, right, middle
    bool uiDown[BUTTONS] = {}, gameDown[BUTTONS] = {};

    Action button(int index, bool down, bool active, bool uiWantsMouse) {
        if (index < 0 || index >= BUTTONS) return Pass;
        if (down) {
            if (active && uiWantsMouse) { uiDown[index] = true; gameDown[index] = false; return SwallowDown; }
            gameDown[index] = true;
            return Pass;
        }
        if (uiDown[index]) { uiDown[index] = false; return SwallowUp; }
        gameDown[index] = false;
        return Pass;
    }
    Action wheel(bool active, bool uiWantsMouse) const { return active && uiWantsMouse ? SwallowWheel : Pass; }
    bool anyUiDown() const { for (int i = 0; i < BUTTONS; ++i) if (uiDown[i]) return true; return false; }
    // Focus loss or shutdown: forget ownership. Returns the buttons ImGui still thinks are down.
    int reset() {
        int mask = 0;
        for (int i = 0; i < BUTTONS; ++i) { if (uiDown[i]) mask |= 1 << i; uiDown[i] = false; gameDown[i] = false; }
        return mask;
    }
};
