package com.example.flutter_rich_haptics

/**
 * Interface defining the contract for haptic feedback players.
 *
 * Each implementation targets a specific Android API level range and uses
 * the most capable vibration API available at that level.
 */
interface HapticPlayer {

    /**
     * Plays a haptic pattern described by an AHAP JSON string.
     *
     * The AHAP (Apple Haptic and Audio Pattern) format is translated into
     * the appropriate Android vibration primitives by each implementation.
     *
     * @param ahapJson A valid AHAP JSON string containing the haptic pattern.
     * @throws IllegalArgumentException if the JSON is malformed or contains
     *         unsupported event types.
     */
    fun play(ahapJson: String)

    /**
     * Stops any currently playing haptic pattern immediately.
     */
    fun stop()

    /**
     * Returns whether this player's underlying vibration API is supported
     * on the current device.
     *
     * @return true if the device supports the vibration mechanism used by
     *         this player; false otherwise.
     */
    fun isSupported(): Boolean
}
