import numpy as np
from typing import List, Tuple, Dict, Optional, Union
import math
import time

class MelodyMatcher:
    def __init__(self):
        self.weights = {
            'dtw_pitch': 0.4,
            'dtw_timing': 0.25,
            'levenshtein': 0.15,
            'lcs': 0.1,
            'cosine': 0.1
        }
        
        # MIDI note range for 3 octaves from C3 to C6
        self.note_range = {
            # C3 to B3 (first octave)
            48: 'C3', 49: 'C#3', 50: 'D3', 51: 'D#3', 52: 'E3', 53: 'F3', 
            54: 'F#3', 55: 'G3', 56: 'G#3', 57: 'A3', 58: 'A#3', 59: 'B3',
            # C4 to B4 (second octave)
            60: 'C4', 61: 'C#4', 62: 'D4', 63: 'D#4', 64: 'E4', 65: 'F4',
            66: 'F#4', 67: 'G4', 68: 'G#4', 69: 'A4', 70: 'A#4', 71: 'B4',
            # C5 to C6 (third octave)
            72: 'C5', 73: 'C#5', 74: 'D5', 75: 'D#5', 76: 'E5', 77: 'F5',
            78: 'F#5', 79: 'G5', 80: 'G#5', 81: 'A5', 82: 'A#5', 83: 'B5',
            84: 'C6'
        }

    def dtw_distance(self, seq1: List[int], seq2: List[int], 
                    timings1: List[float] = None, timings2: List[float] = None,
                    durations1: List[float] = None, durations2: List[float] = None,
                    pitch_weight: float = 0.6, timing_weight: float = 0.4) -> Tuple[float, float, float, List[Dict]]:
        """
        Enhanced Dynamic Time Warping algorithm that considers both pitch and timing
        
        Args:
            seq1: First melody (list of MIDI note numbers)
            seq2: Second melody (list of MIDI note numbers)
            timings1: Onset times for first melody (in ms from start)
            timings2: Onset times for second melody (in ms from start)
            durations1: Note durations for first melody (in ms)
            durations2: Note durations for second melody (in ms)
            pitch_weight: Weight given to pitch differences (0-1)
            timing_weight: Weight given to timing differences (0-1)
            
        Returns:
            Tuple of (combined_distance, pitch_distance, timing_distance, note_details)
        """
        n, m = len(seq1), len(seq2)
        
        # Create DTW matrix for combined cost
        dtw_matrix = np.zeros((n + 1, m + 1))
        dtw_matrix.fill(float('inf'))
        dtw_matrix[0, 0] = 0
        
        # Create separate matrices for pitch and timing if needed
        pitch_matrix = np.zeros((n + 1, m + 1))
        pitch_matrix.fill(float('inf'))
        pitch_matrix[0, 0] = 0
        
        timing_matrix = np.zeros((n + 1, m + 1))
        timing_matrix.fill(float('inf'))
        timing_matrix[0, 0] = 0
        
        # Store alignment details for output
        details = []
        
        # Adjust timing to align starting points if timings are provided
        # This handles differences in when the user started playing
        adjusted_timings2 = timings2
        if timings1 and timings2:
            timing_offset = timings2[0] - timings1[0]
            adjusted_timings2 = [t - timing_offset for t in timings2]
        
        # Track alignment path for generating note details
        alignment_path = []
        
        # Constants for normalizing costs - UPDATED FOR MORE BALANCED DISCRIMINATION
        MAX_PITCH_DIFF = 24.0  # Reduced from 127 to 24 (2 octaves) for more realistic scaling
        MAX_TIMING_DIFF = 600.0  # Increased from 300ms to 600ms - more forgiving
        MAX_DURATION_DIFF = 350.0  # Increased from 200ms to 350ms - more forgiving
        
        # Fill the DTW matrices
        for i in range(1, n + 1):
            for j in range(1, m + 1):
                # Calculate pitch difference (normalized 0-1)
                pitch_diff = abs(seq1[i-1] - seq2[j-1]) / MAX_PITCH_DIFF
                # Apply non-linear transformation to pitch differences
                pitch_diff = min(pitch_diff * 1.5, 1.0)  # Make small differences more significant
                
                pitch_matrix[i, j] = pitch_diff + min(
                    pitch_matrix[i-1, j],
                    pitch_matrix[i, j-1],
                    pitch_matrix[i-1, j-1]
                )
                
                # Calculate timing difference if available
                if timings1 and adjusted_timings2 and durations1 and durations2:
                    # Onset timing difference (normalized 0-1)
                    timing_diff = abs(timings1[i-1] - adjusted_timings2[j-1]) / MAX_TIMING_DIFF
                    # Apply non-linear transformation to timing differences (less aggressive)
                    timing_diff = min(timing_diff * 1.2, 1.0)  # Reduced from 1.5 to 1.2
                    
                    # Duration difference (normalized 0-1)
                    duration_diff = abs(durations1[i-1] - durations2[j-1]) / MAX_DURATION_DIFF
                    # Apply non-linear transformation to duration differences (less aggressive)
                    duration_diff = min(duration_diff * 1.2, 1.0)  # Reduced from 1.5 to 1.2
                    
                    # Combined timing cost (weighting onset more than duration)
                    timing_cost = 0.7 * timing_diff + 0.3 * duration_diff
                    
                    timing_matrix[i, j] = timing_cost + min(
                        timing_matrix[i-1, j],
                        timing_matrix[i, j-1],
                        timing_matrix[i-1, j-1]
                    )
                else:
                    # No timing data available
                    timing_cost = 0
                    timing_matrix[i, j] = timing_matrix[i-1, j-1]
                
                # Calculate combined cost
                combined_cost = (pitch_weight * pitch_diff) + (timing_weight * timing_cost if timings1 else 0)
                dtw_matrix[i, j] = combined_cost + min(
                    dtw_matrix[i-1, j],    # insertion
                    dtw_matrix[i, j-1],    # deletion
                    dtw_matrix[i-1, j-1]   # match
                )
        
        # Trace back to find alignment path
        i, j = n, m
        path = []
        while i > 0 and j > 0:
            path.append((i-1, j-1))
            
            # Find which direction we came from
            min_val = min(dtw_matrix[i-1, j-1], dtw_matrix[i-1, j], dtw_matrix[i, j-1])
            
            if min_val == dtw_matrix[i-1, j-1]:
                i -= 1
                j -= 1
            elif min_val == dtw_matrix[i-1, j]:
                i -= 1
            else:
                j -= 1
        
        path.reverse()
        
        # Generate note detail information
        note_details = []
        for idx, (i, j) in enumerate(path):
            # Calculate if this is an exact pitch match
            is_correct_pitch = seq1[i] == seq2[j]
            
            # Create detail record
            detail = {
                'index': idx,
                'target_note': seq1[i],
                'target_note_name': self.note_range.get(seq1[i], f"Unknown({seq1[i]})"),
                'played_note': seq2[j],
                'played_note_name': self.note_range.get(seq2[j], f"Unknown({seq2[j]})"),
                'is_correct_pitch': is_correct_pitch
            }
            
            # Add timing details if available
            if timings1 and adjusted_timings2 and durations1 and durations2:
                onset_error = abs(timings1[i] - adjusted_timings2[j])
                duration_error = abs(durations1[i] - durations2[j])
                
                detail.update({
                    'onset_error': onset_error,
                    'duration_error': duration_error,
                    'target_onset': timings1[i],
                    'played_onset': adjusted_timings2[j],
                    'target_duration': durations1[i],
                    'played_duration': durations2[j]
                })
            
            note_details.append(detail)
        
        # Calculate exact matches for pitch accuracy
        pitch_matches = sum(1 for detail in note_details if detail['is_correct_pitch'])
        pitch_accuracy = pitch_matches / len(note_details) if note_details else 0.0
        
        # Calculate timing accuracy if data available
        if timings1 and timings2 and durations1 and durations2:
            onset_errors = [detail['onset_error'] for detail in note_details]
            duration_errors = [detail['duration_error'] for detail in note_details]
            
            # Normalize errors (0 = max error, 1 = perfect)
            norm_onset_errors = [1 - min(error / MAX_TIMING_DIFF, 1.0) for error in onset_errors]
            norm_duration_errors = [1 - min(error / MAX_DURATION_DIFF, 1.0) for error in duration_errors]
            
            # Apply non-linear transformation to make algorithm more discriminating (less aggressive)
            norm_onset_errors = [min(score ** 1.2, 1.0) for score in norm_onset_errors]  # Cap at 1.0 after transformation
            norm_duration_errors = [min(score ** 1.2, 1.0) for score in norm_duration_errors]  # Cap at 1.0 after transformation
            
            onset_accuracy = sum(norm_onset_errors) / len(norm_onset_errors) if norm_onset_errors else 0.0
            duration_accuracy = sum(norm_duration_errors) / len(norm_duration_errors) if norm_duration_errors else 0.0
            
            # Combined timing accuracy (weight onset more than duration)
            timing_accuracy = min(0.7 * onset_accuracy + 0.3 * duration_accuracy, 1.0)  # Cap at 1.0
        else:
            timing_accuracy = 0.0
        
        # Normalize DTW distances to 0-1 scale
        # For DTW, lower values are better, so we invert to get "similarity"
        # We now use a more realistic maximum distance for better discrimination
        adjusted_max_dist = min(n, m) * 0.5  # More realistic expectation for maximum distance
        
        normalized_combined = 1.0 - min(dtw_matrix[n, m] / adjusted_max_dist, 1.0)
        normalized_pitch = 1.0 - min(pitch_matrix[n, m] / adjusted_max_dist, 1.0)
        
        # Apply non-linear transformation to make scores more discriminating (less aggressive for pitch)
        normalized_combined = min(normalized_combined ** 1.5, 1.0)  # Cap at 1.0 after transformation
        normalized_pitch = min(normalized_pitch ** 1.5, 1.0)  # Cap at 1.0 after transformation
        
        # Use calculated timing accuracy (already transformed and capped)
        normalized_timing = timing_accuracy
        
        return normalized_combined, normalized_pitch, normalized_timing, note_details

    def levenshtein_distance(self, seq1: List[int], seq2: List[int]) -> int:
        """
        Levenshtein Distance for note accuracy
        """
        n, m = len(seq1), len(seq2)
        dp = [[0 for _ in range(m + 1)] for _ in range(n + 1)]

        for i in range(n + 1):
            dp[i][0] = i
        for j in range(m + 1):
            dp[0][j] = j

        for i in range(1, n + 1):
            for j in range(1, m + 1):
                if seq1[i-1] == seq2[j-1]:
                    dp[i][j] = dp[i-1][j-1]
                else:
                    dp[i][j] = min(
                        dp[i-1][j] + 1,    # deletion
                        dp[i][j-1] + 1,    # insertion
                        dp[i-1][j-1] + 1   # substitution
                    )

        return dp[n][m]

    def lcs_length(self, seq1: List[int], seq2: List[int]) -> int:
        """
        Longest Common Subsequence for sequence matching
        """
        n, m = len(seq1), len(seq2)
        dp = [[0 for _ in range(m + 1)] for _ in range(n + 1)]

        for i in range(1, n + 1):
            for j in range(1, m + 1):
                if seq1[i-1] == seq2[j-1]:
                    dp[i][j] = dp[i-1][j-1] + 1
                else:
                    dp[i][j] = max(dp[i-1][j], dp[i][j-1])

        return dp[n][m]

    def cosine_similarity(self, seq1: List[int], seq2: List[int]) -> float:
        """
        Cosine Similarity for overall melody comparison
        """
        # Convert sequences to frequency vectors
        max_note = max(max(seq1) if seq1 else 0, max(seq2) if seq2 else 0) + 1
        vec1 = np.zeros(max_note)
        vec2 = np.zeros(max_note)

        for note in seq1:
            vec1[note] += 1
        for note in seq2:
            vec2[note] += 1

        # Calculate cosine similarity
        dot_product = np.dot(vec1, vec2)
        norm1 = np.linalg.norm(vec1)
        norm2 = np.linalg.norm(vec2)

        if norm1 == 0 or norm2 == 0:
            return 0.0

        similarity = dot_product / (norm1 * norm2)
        
        # Apply non-linear transformation to make more discriminating
        similarity = similarity ** 1.5  # Apply exponent to make high similarities more significant
        
        return similarity

    def normalize_score(self, score: float, max_score: float) -> float:
        """
        Normalize scores to a 0-1 range
        """
        if max_score <= 0:
            return 0
            
        # Ensure score doesn't exceed max_score
        score = min(score, max_score)
        
        normalized = 1 - (score / max_score)
        
        # Apply non-linear transformation to make scores more discriminating
        normalized = normalized ** 1.5  # Apply exponent to spread out high values
        
        # Cap at 1.0 to prevent scores over 100%
        return min(normalized, 1.0)

    def compare_melodies(self, melody1: List[int], melody2: List[int], 
                          timings1: List[float] = None, timings2: List[float] = None, 
                          durations1: List[float] = None, durations2: List[float] = None) -> Dict[str, Union[float, Dict]]:
        """
        Compare two melodies using all algorithms and return weighted score
        
        Args:
            melody1: Target melody (list of MIDI note numbers)
            melody2: Played melody (list of MIDI note numbers)
            timings1: Note onset times for target melody (in ms from start)
            timings2: Note onset times for played melody (in ms from start)
            durations1: Note durations for target melody (in ms)
            durations2: Note durations for played melody (in ms)
            
        Returns:
            Dictionary with final score and individual scores
        """
        start_time = time.time()
        
        if not melody1 or not melody2:
            return {
                'final_score': 0.0,
                'pitch_accuracy': 0.0,
                'timing_accuracy': 0.0,
                'individual_scores': {},
                'note_details': [],
                'matching_runtime_nocom': 0.0
            }
        
        # Run enhanced DTW with timing information if available
        dtw_combined, dtw_pitch, dtw_timing, note_details = self.dtw_distance(
            melody1, melody2, 
            timings1, timings2, 
            durations1, durations2
        )
            
        # Calculate other algorithm scores
        levenshtein_score = self.levenshtein_distance(melody1, melody2)
        lcs_score = self.lcs_length(melody1, melody2)
        cosine_score = self.cosine_similarity(melody1, melody2)
        
        # Normalize scores
        max_levenshtein = max(len(melody1), len(melody2))
        max_lcs = min(len(melody1), len(melody2))

        # Apply non-linear transformations to scores for more discrimination
        normalized_levenshtein = min(self.normalize_score(levenshtein_score, max_levenshtein), 1.0)
        normalized_lcs = min((lcs_score / max_lcs if max_lcs > 0 else 0) ** 1.5, 1.0)  # Apply exponent and cap

        # Ensure all scores are capped at 1.0
        normalized_scores = {
            'dtw_combined': min(dtw_combined, 1.0),
            'dtw_pitch': min(dtw_pitch, 1.0),
            'dtw_timing': min(dtw_timing, 1.0),
            'levenshtein': normalized_levenshtein,
            'lcs': normalized_lcs,
            'cosine': min(cosine_score, 1.0)
        }
        
        # Count exact pitch matches from the note details
        exact_matches = sum(1 for detail in note_details if detail.get('is_correct_pitch', False))
        total_notes = len(note_details)
        pitch_accuracy = (exact_matches / total_notes if total_notes > 0 else 0.0)
        
        # Apply non-linear transformation to pitch accuracy (less aggressive)
        pitch_accuracy = min(pitch_accuracy ** 1.3, 1.0)  # Cap at 1.0 after transformation
        
        # Calculate weighted final score
        if timings1 and timings2 and durations1 and durations2:
            # If timing data available, use combined DTW score
            final_score = (
                (self.weights['dtw_pitch'] * normalized_scores['dtw_pitch']) +
                (self.weights['dtw_timing'] * normalized_scores['dtw_timing']) +
                (self.weights['levenshtein'] * normalized_scores['levenshtein']) +
                (self.weights['lcs'] * normalized_scores['lcs']) +
                (self.weights['cosine'] * normalized_scores['cosine'])
            )
        else:
            # If no timing data, redistribute timing weight to other algorithms
            pitch_weight = sum(weight for algo, weight in self.weights.items() if 'timing' not in algo)
            final_score = (
                (self.weights['dtw_pitch'] * normalized_scores['dtw_pitch']) +
                (self.weights['levenshtein'] * normalized_scores['levenshtein']) +
                (self.weights['lcs'] * normalized_scores['lcs']) +
                (self.weights['cosine'] * normalized_scores['cosine'])
            ) / pitch_weight
        
        # Apply final non-linear transformation to make overall score more discriminating (less aggressive)
        final_score = min(final_score ** 1.15, 1.0)  # Cap at 1.0 after transformation
        
        # Calculate runtime in milliseconds
        end_time = time.time()
        runtime_ms = (end_time - start_time) * 1000  # Convert to milliseconds
        
        # Prepare response
        result = {
            'final_score': final_score,
            'pitch_accuracy': pitch_accuracy,
            'individual_scores': normalized_scores,
            'note_details': note_details,
            'matching_runtime_nocom': runtime_ms
        }
        
        # Add timing specific results if available
        if timings1 and timings2 and durations1 and durations2:
            result['timing_accuracy'] = normalized_scores['dtw_timing']
            
            # Extract onset and duration accuracies from note details
            if note_details:
                onset_errors = [detail.get('onset_error', 0) for detail in note_details if 'onset_error' in detail]
                duration_errors = [detail.get('duration_error', 0) for detail in note_details if 'duration_error' in detail]
                
                if onset_errors:
                    max_timing_error = 600.0  # Increased from 300ms to 600ms
                    norm_onset_errors = [1 - min(error / max_timing_error, 1.0) for error in onset_errors]
                    # Apply non-linear transformation (less aggressive)
                    norm_onset_errors = [min(score ** 1.2, 1.0) for score in norm_onset_errors]  # Cap at 1.0 after transformation
                    onset_accuracy = sum(norm_onset_errors) / len(norm_onset_errors)
                    result['onset_accuracy'] = onset_accuracy
                
                if duration_errors:
                    max_duration_error = 350.0  # Increased from 200ms to 350ms
                    norm_duration_errors = [1 - min(error / max_duration_error, 1.0) for error in duration_errors]
                    # Apply non-linear transformation (less aggressive)
                    norm_duration_errors = [min(score ** 1.2, 1.0) for score in norm_duration_errors]  # Cap at 1.0 after transformation
                    duration_accuracy = sum(norm_duration_errors) / len(norm_duration_errors)
                    result['duration_accuracy'] = duration_accuracy
        else:
            result['timing_accuracy'] = 0.0
            
        return result 
        
    def get_difficulty_estimate(self, melody: List[int]) -> Dict[str, float]:
        """
        Estimate the difficulty level of a melody based on various musical factors
        
        Args:
            melody: List of MIDI note numbers
            
        Returns:
            Dictionary with difficulty scores and analysis
        """
        if not melody or len(melody) < 2:
            return {
                'difficulty_score': 0.0,
                'factors': {
                    'length': 0.0,
                    'interval_complexity': 0.0,
                    'range': 0.0,
                    'unique_notes': 0.0
                }
            }
        
        # Calculate various difficulty factors
        
        # 1. Length factor (longer melodies are harder)
        length = len(melody)
        # Normalize length to 0-1 scale (assume 32 notes is max difficulty)
        length_factor = min(length / 32.0, 1.0)
        
        # 2. Interval complexity (larger intervals are harder)
        intervals = [abs(melody[i] - melody[i-1]) for i in range(1, len(melody))]
        avg_interval = sum(intervals) / len(intervals) if intervals else 0
        # Normalize to 0-1 (assume average interval of 12 semitones is max difficulty)
        interval_factor = min(avg_interval / 12.0, 1.0)
        
        # 3. Range complexity (wider range is harder)
        melody_range = max(melody) - min(melody) if melody else 0
        # Normalize to 0-1 (assume 24 semitones/2 octaves is max difficulty)
        range_factor = min(melody_range / 24.0, 1.0)
        
        # 4. Unique notes factor (more unique notes is harder)
        unique_notes = len(set(melody))
        # Normalize to 0-1 (assume 12 unique notes is max difficulty)
        unique_factor = min(unique_notes / 12.0, 1.0)
        
        # Calculate weighted difficulty score
        difficulty_score = (
            0.3 * length_factor +
            0.3 * interval_factor + 
            0.2 * range_factor +
            0.2 * unique_factor
        )
        
        # Return difficulty estimate and factor breakdown
        return {
            'difficulty_score': difficulty_score,
            'difficulty_level': self._difficulty_level_from_score(difficulty_score),
            'factors': {
                'length': length_factor,
                'interval_complexity': interval_factor,
                'range': range_factor,
                'unique_notes': unique_factor
            },
            'analysis': {
                'length': length,
                'average_interval': avg_interval,
                'range_semitones': melody_range,
                'unique_notes': unique_notes
            }
        }
    
    def _difficulty_level_from_score(self, score: float) -> str:
        """Convert numerical difficulty score to text level"""
        if score < 0.2:
            return "Very Easy"
        elif score < 0.4:
            return "Easy"
        elif score < 0.6:
            return "Intermediate"
        elif score < 0.8:
            return "Hard"
        else:
            return "Very Hard" 