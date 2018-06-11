//
//  FreesoundAnalysisDescriptors.swift
//  FreesoundKit
//
//  Copyright © 2018 Nikhil Singh. All rights reserved.
//

import Foundation

/// Protocol for various descriptors.
public protocol FreesoundDescriptor {
    var string: String { get }
}

/// Freesound sound analysis descriptors.
public enum FreesoundAnalysisDescriptors {
    public enum LowLevel: String, FreesoundDescriptor {
        case spectral_complexity,
        silence_rate_20dB,
        erb_bands,
        average_loudness,
        spectral_rms,
        spectral_kurtosis,
        barkbands_kurtosis,
        scvalleys,
        spectral_spread,
        pitch,
        dissonance,
        spectral_energyband_high,
        gfcc,
        spectral_flux,
        silence_rate_30dB,
        spectral_contrast,
        spectral_energyband_middle_high,
        barkbands_spread,
        spectral_centroid,
        pitch_salience,
        silence_rate_60dB,
        spectral_entropy,
        spectral_rolloff,
        barkbands,
        spectral_energyband_low,
        barkbands_skewness,
        pitch_instantaneous_confidence,
        spectral_energyband_middle_low,
        spectral_strongpeak,
        startFrame,
        spectral_decrease,
        stopFrame,
        mfcc,
        spectral_energy,
        spectral_flatness_db,
        frequency_bands,
        zerocrossingrate,
        spectral_skewness,
        hfc,
        spectral_crest
        
        public var string: String {
            return "lowlevel.\(self.rawValue)"
        }
    }
    
    public enum Rhythm: String, FreesoundDescriptor {
        case first_peak_bpm,
        onset_times,
        beats_count,
        beats_loudness,
        first_peak_spread,
        second_peak_weight,
        bpm,
        bpm_intervals,
        onset_count,
        second_peak_spread,
        beats_loudness_band_ratio,
        second_peak_bpm,
        onset_rate,
        beats_position,
        first_peak_weight
        
        public var string: String {
            return "rhythm.\(self.rawValue)"
        }
    }
    
    public enum Tonal: String, FreesoundDescriptor {
        case hpcp_entropy,
        chords_scale,
        chords_number_rate,
        key_strength,
        chords_progression,
        key_scale,
        chords_strength,
        key_key,
        chords_changes_rate,
        chords_count,
        hpcp_crest,
        chords_histogram,
        chords_key,
        tuning_frequency,
        hpcp_peak_count,
        hpcp
        
        public var string: String {
            return "tonal.\(self.rawValue)"
        }
    }
    
    public enum SFX: String, FreesoundDescriptor {
        case temporal_decrease,
        inharmonicity,
        pitch_min_to_total,
        tc_to_total,
        der_av_after_max,
        pitch_max_to_total,
        temporal_spread,
        temporal_kurtosis,
        logattacktime,
        temporal_centroid,
        tristimulus,
        max_der_before_max,
        strongdecay,
        pitch_centroid,
        duration,
        temporal_skewness,
        effective_duration,
        max_to_total,
        oddtoevenharmonicenergyratio,
        pitch_after_max_to_before_max_energy_ratio
        
        public var string: String {
            return "sfx.\(self.rawValue)"
        }
    }
}
