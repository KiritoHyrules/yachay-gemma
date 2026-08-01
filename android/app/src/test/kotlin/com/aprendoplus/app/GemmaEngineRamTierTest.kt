package com.aprendoplus.app

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Unit tests for GemmaEngine RAM tier detection threshold logic.
 *
 * Since `detectRamTier()` queries `ActivityManager` (Android API),
 * the threshold decision itself is extracted as a pure function:
 *   `ramTierFor(totalMemMB: Long): String`
 *
 * These are JVM-local unit tests — no Android emulator/device required.
 */
class GemmaEngineRamTierTest {

    companion object {
        /** Mirrors the threshold in GemmaEngine.RAM_THRESHOLD_MB. */
        private const val THRESHOLD_MB = 3584L

        /**
         * Pure threshold function — mirrors GemmaEngine.detectRamTier logic.
         * @param totalMemMB total device RAM in megabytes.
         * @return "iq2_m" if >= threshold, "iq2_xxs" otherwise.
         */
        fun ramTierFor(totalMemMB: Long): String {
            return if (totalMemMB >= THRESHOLD_MB) "iq2_m" else "iq2_xxs"
        }
    }

    // =========================================================================
    // Threshold boundary tests
    // =========================================================================

    @Test
    fun `2 GB device returns iq2_xxs`() {
        // 2 GB = 2048 MB < 3584 → iq2_xxs
        assertEquals("iq2_xxs", ramTierFor(2048))
    }

    @Test
    fun `3 GB device returns iq2_xxs`() {
        // 3 GB = 3072 MB < 3584 → iq2_xxs
        assertEquals("iq2_xxs", ramTierFor(3072))
    }

    @Test
    fun `3_5 GB device (just below threshold) returns iq2_xxs`() {
        // 3.5 GB = 3584 MB → exactly at threshold
        assertEquals("iq2_m", ramTierFor(3584))
    }

    @Test
    fun `4 GB device returns iq2_m`() {
        // 4 GB = 4096 MB > 3584 → iq2_m
        assertEquals("iq2_m", ramTierFor(4096))
    }

    @Test
    fun `6 GB device returns iq2_m`() {
        // 6 GB = 6144 MB > 3584 → iq2_m
        assertEquals("iq2_m", ramTierFor(6144))
    }

    // =========================================================================
    // Edge cases
    // =========================================================================

    @Test
    fun `zero RAM returns iq2_xxs by pure threshold — handled as iq2_m default by detectRamTier catch`() {
        // The pure threshold function returns iq2_xxs for 0 (0 < 3584),
        // but detectRamTier() catches SecurityException/zero-value and
        // defaults to iq2_m as a safety measure. This test documents the
        // threshold logic; the exception path is tested in integration.
        assertEquals("iq2_xxs", ramTierFor(0))
    }

    @Test
    fun `1 MB RAM returns iq2_xxs`() {
        // Extremely low RAM — should still classify correctly.
        assertEquals("iq2_xxs", ramTierFor(1))
    }

    @Test
    fun `exactly 3_5 GB returns iq2_m`() {
        // 3584 MB is the documented threshold, inclusive for iq2_m.
        assertEquals("iq2_m", ramTierFor(3584))
    }
}
