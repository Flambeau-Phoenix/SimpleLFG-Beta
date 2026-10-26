#pragma once
#include <cstdint>
#include <cstring>

// Pure routing policy. No game objects, callbacks, allocations or simulated input.
struct ExtraBarsPolicy {
    int prefix = 0, key = 0, mode = 0, generation = 0;
    bool eligible = false, recovering = true, toggled = false;
    bool down[256] = {}, blocked[256] = {};
    int queued = 0, suppressed = 0;
    int bindings[256] = {}, pending[32] = {};
    static bool validPrefix(int vk) { return vk == 5 || vk == 6 || vk == 88 || vk == 67 || vk == 9 || vk == 20; }
    static bool validKey(int vk) {
        return vk >= 8 && vk < 256 && vk != 13 && vk != 27 && vk != 16 && vk != 17 && vk != 18
            && vk != 91 && vk != 92 && vk != 117 && vk != 123;
    }
    void cancel() { eligible = false; recovering = true; toggled = false; queued = 0; }
    void focusLost() {
        cancel();
        for (int i = 0; i < 256; ++i) { down[i] = false; blocked[i] = false; }
    }
    void configure(int p, int k, int m, bool allowed, int gen, bool held, bool modifiers) {
        int keys[256] = {};
        if (k > 0 && k < 256) keys[k] = 1;
        configureMany(p, keys, m, allowed, gen, held, modifiers);
        key = k;
    }
    void configureMany(int p, const int* keys, int m, bool allowed, int gen, bool held, bool modifiers) {
        bool changed = p != prefix || m != mode || gen != generation || std::memcmp(bindings, keys, sizeof(bindings)) != 0;
        if (changed || !allowed || !eligible) { recovering = true; toggled = false; queued = 0; }
        prefix = p; mode = m; generation = gen;
        bool any = false, valid = true;
        for (int i=0; i<256; ++i) {
            if (keys[i] != 0) { any = true; if (!validKey(i) || (m != 3 && i == p) || keys[i] < 1) valid = false; }
            bindings[i] = keys[i];
        }
        eligible = allowed && (m == 3 ? p == 0 : validPrefix(p)) && any && valid && (m == 1 || m == 2 || m == 3);
        // Physical held-key ownership survives config/editor changes until its paired up.
        if (eligible && recovering && !held && !modifiers) {
            recovering = false;
            for (int i = 0; i < 256; ++i) if (!blocked[i]) down[i] = false;
        }
    }
    bool active() const { return eligible && !recovering && (mode == 3 || (mode == 2 ? toggled : down[prefix])); }
    bool event(int vk, bool pressed, bool repeat, bool modifiers) {
        if (vk <= 0 || vk >= 256) return false;
        if (!pressed) {
            bool eat = blocked[vk];
            blocked[vk] = false; down[vk] = false;
            return eat;
        }
        bool fresh = !down[vk] && !repeat;
        down[vk] = true;
        if (blocked[vk]) return true; // Preserve ownership even after prefix/gate release.
        if (!fresh) return false; // Native-down repeats stay native even if the page changed.
        if (vk == 13 || vk == 27 || vk == 117 || vk == 123) { cancel(); return false; }
        if (!eligible || recovering || modifiers) return false;
        if (mode != 3 && vk == prefix) {
            if (mode == 2) toggled = !toggled;
            return false; // The prefix itself remains a native input.
        }
        if (bindings[vk] <= 0 || !active()) return false;
        blocked[vk] = true;
        ++suppressed;
        if (queued < 32) pending[queued++] = bindings[vk];
        return true;
    }
    bool take(int gen) {
        return takeToken(gen) != 0;
    }
    int takeToken(int gen) {
        if (!eligible || recovering || gen != generation) { queued = 0; return 0; }
        if (queued == 0) return 0;
        int token = pending[0];
        --queued;
        for (int i=0; i<queued; ++i) pending[i] = pending[i+1];
        return token;
    }
    bool hasBlocked() const { for (int i = 0; i < 256; ++i) if (blocked[i]) return true; return false; }
};
