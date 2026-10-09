package rocks.brandstaetter.brandyfly_native

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Process
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.PI
import kotlin.math.sin

/**
 * Real-time low-latency PCM audio synthesizer for acoustic vario feedback on Android.
 * Generates phase-continuous waveforms with anti-click envelope ramps on a dedicated audio thread.
 */
class AudioVarioSynthesizer {

    private val sampleRate = 44100
    private val isRunning = AtomicBoolean(false)
    private var audioTrack: AudioTrack? = null
    private var synthesisThread: Thread? = null

    // Lock-free atomic / volatile audio parameters
    @Volatile private var targetFrequencyHz: Double = 0.0
    @Volatile private var currentFrequencyHz: Double = 0.0
    @Volatile private var targetCadenceMs: Int = 500
    @Volatile private var targetDutyCycle: Double = 0.5
    @Volatile private var masterVolume: Double = 0.8
    @Volatile private var isMuted: Boolean = false
    @Volatile private var state: String = "silent"

    fun start(): Boolean {
        if (isRunning.get()) return true

        val minBufSize = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        val bufferSize = (minBufSize * 2).coerceAtLeast(1024)

        try {
            audioTrack = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(sampleRate)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build()
                )
                .setBufferSizeInBytes(bufferSize)
                .setTransferMode(AudioTrack.MODE_STREAM)
                .setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
                .build()

            audioTrack?.play()
            isRunning.set(true)

            synthesisThread = Thread {
                runSynthesisLoop()
            }.apply {
                name = "brandyfly-audio-vario"
                priority = Thread.MAX_PRIORITY
                start()
            }
            return true
        } catch (e: Exception) {
            isRunning.set(false)
            audioTrack?.release()
            audioTrack = null
            return false
        }
    }

    fun stop(): Boolean {
        isRunning.set(false)
        try {
            synthesisThread?.interrupt()
            synthesisThread?.join(500)
        } catch (_: InterruptedException) {
        }
        synthesisThread = null

        try {
            audioTrack?.stop()
            audioTrack?.release()
        } catch (_: Exception) {
        }
        audioTrack = null
        return true
    }

    fun updateTone(
        stateStr: String,
        frequencyHz: Double,
        cadenceMs: Int,
        dutyCycle: Double,
        volume: Double,
        muted: Boolean
    ) {
        state = stateStr
        targetFrequencyHz = frequencyHz
        targetCadenceMs = cadenceMs.coerceAtLeast(10)
        targetDutyCycle = dutyCycle.coerceIn(0.0, 1.0)
        masterVolume = volume.coerceIn(0.0, 1.0)
        isMuted = muted
    }

    fun setVolume(volume: Double) {
        masterVolume = volume.coerceIn(0.0, 1.0)
    }

    fun setMuted(muted: Boolean) {
        isMuted = muted
    }

    private fun runSynthesisLoop() {
        try {
            Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)
        } catch (_: Exception) {
        }

        val chunkSize = 256
        val buffer = ShortArray(chunkSize)
        var phase = 0.0
        var sampleIndexInPeriod = 0L
        var currentEnvelopeGain = 0.0
        val rampSamples = (sampleRate * 0.002).toInt().coerceAtLeast(1) // 2ms ramp
        val rampStep = 1.0 / rampSamples

        while (isRunning.get()) {
            val track = audioTrack ?: break
            val targetFreq = targetFrequencyHz
            val cadenceMs = targetCadenceMs
            val dutyCycle = targetDutyCycle
            val vol = masterVolume
            val muted = isMuted
            val currentState = state

            val samplesPerPeriod = ((sampleRate * cadenceMs) / 1000L).coerceAtLeast(1L)
            val activeSamplesPerPeriod = (samplesPerPeriod * dutyCycle).toLong()

            for (i in 0 until chunkSize) {
                // Smooth frequency slew to prevent pitch stepping clicks
                if (currentFrequencyHz < targetFreq) {
                    currentFrequencyHz = (currentFrequencyHz + 0.5).coerceAtMost(targetFreq)
                } else if (currentFrequencyHz > targetFreq) {
                    currentFrequencyHz = (currentFrequencyHz - 0.5).coerceAtLeast(targetFreq)
                }

                val isSoundActive = when {
                    muted || currentState == "silent" || targetFreq <= 10.0 -> false
                    currentState == "sink" -> true
                    else -> (sampleIndexInPeriod % samplesPerPeriod) < activeSamplesPerPeriod
                }

                // Envelope ramps
                if (isSoundActive) {
                    if (currentEnvelopeGain < 1.0) {
                        currentEnvelopeGain = (currentEnvelopeGain + rampStep).coerceAtMost(1.0)
                    }
                } else {
                    if (currentEnvelopeGain > 0.0) {
                        currentEnvelopeGain = (currentEnvelopeGain - rampStep).coerceAtLeast(0.0)
                    }
                }

                if (currentEnvelopeGain > 0.0001 && currentFrequencyHz > 10.0) {
                    phase += 2.0 * PI * currentFrequencyHz / sampleRate
                    if (phase >= 2.0 * PI) {
                        phase -= 2.0 * PI
                    }
                    val sample = sin(phase) * currentEnvelopeGain * vol * 32767.0
                    buffer[i] = sample.toInt().coerceIn(-32768, 32767).toShort()
                } else {
                    buffer[i] = 0
                }

                sampleIndexInPeriod++
                if (sampleIndexInPeriod >= samplesPerPeriod * 1000L) {
                    sampleIndexInPeriod = sampleIndexInPeriod % samplesPerPeriod
                }
            }

            track.write(buffer, 0, chunkSize)
        }
    }
}
