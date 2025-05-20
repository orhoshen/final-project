import numpy as np
import time
from typing import List, Dict, Any, Tuple

class MelodyMatcher:
    """
    A class for comparing melodies and calculating similarity scores
    using various algorithms like DTW, Levenshtein distance, etc.
    """
    
    def __init__(self):
        """Initialize the melody matcher."""
        pass
        
    def compare_melodies(self, melody1: List[int], melody2: List[int]) -> Dict[str, Any]:
        """
        Compare two melodies and return a detailed comparison result with multiple metrics.
        
        Args:
            melody1: First melody (list of MIDI note numbers)
            melody2: Second melody (list of MIDI note numbers)
            
        Returns:
            Dictionary with detailed comparison metrics
        """
        start_time = time.time()
        
        # Extract timing data if available (future extension)
        # For now, we'll work only with pitch sequences
        
        # Calculate individual algorithm scores
        dtw_score = self._calculate_dtw(melody1, melody2)
        levenshtein_score = self._calculate_levenshtein(melody1, melody2)
        lcs_score = self._calculate_lcs(melody1, melody2)
        cosine_score = self._calculate_cosine_similarity(melody1, melody2)
        
        # Calculate accuracy metrics
        pitch_accuracy = self._calculate_pitch_accuracy(melody1, melody2)
        
        # Calculate additional metrics (mock timing accuracy for this example)
        timing_accuracy = 0.85  # Mock value
        onset_accuracy = 0.90  # Mock value
        duration_accuracy = 0.87  # Mock value
        
        # Calculate the final weighted score
        # Use a weighted average of the different algorithm scores
        final_score = (
            0.3 * dtw_score +
            0.2 * levenshtein_score +
            0.2 * lcs_score +
            0.3 * cosine_score
        )
        
        # Create detailed note-by-note comparison
        note_details = self._create_note_details(melody1, melody2)
        
        # Structure the detailed result
        return {
            "final_score": final_score,
            "pitch_accuracy": pitch_accuracy,
            "timing_accuracy": timing_accuracy,
            "onset_accuracy": onset_accuracy,
            "duration_accuracy": duration_accuracy,
            "individual_scores": {
                "dtw_combined": dtw_score,
                "dtw_pitch": dtw_score * 0.95,  # Slightly different for demonstration
                "dtw_timing": dtw_score * 1.05,  # Slightly different for demonstration
                "levenshtein": levenshtein_score,
                "lcs": lcs_score,
                "cosine": cosine_score
            },
            "note_details": note_details
        }
    
    def _calculate_dtw(self, seq1: List[int], seq2: List[int]) -> float:
        """
        Calculate normalized DTW (Dynamic Time Warping) distance.
        Returns similarity score between 0-1 (1 is most similar).
        """
        # Convert lists to numpy arrays
        arr1 = np.array(seq1)
        arr2 = np.array(seq2)
        
        # Create DTW matrix
        n, m = len(arr1), len(arr2)
        dtw_matrix = np.zeros((n+1, m+1))
        dtw_matrix.fill(float('inf'))
        dtw_matrix[0, 0] = 0
        
        # Fill the matrix
        for i in range(1, n+1):
            for j in range(1, m+1):
                cost = abs(arr1[i-1] - arr2[j-1])
                dtw_matrix[i, j] = cost + min(
                    dtw_matrix[i-1, j],     # insertion
                    dtw_matrix[i, j-1],     # deletion
                    dtw_matrix[i-1, j-1]    # substitution
                )
                
        # Normalize the final distance (0-1 range where 1 is perfect match)
        # Using max of diagonal path length and absolute max distance
        max_possible_distance = np.max(np.abs(arr1[:, None] - arr2)) * max(n, m)
        # Avoid division by zero
        if max_possible_distance == 0:
            return 1.0  # Perfect match
        
        # Convert distance to similarity score (1 - normalized_distance)
        similarity = 1.0 - dtw_matrix[n, m] / max_possible_distance
        return max(0.0, min(1.0, similarity))  # Clamp to [0, 1]
    
    def _calculate_levenshtein(self, seq1: List[int], seq2: List[int]) -> float:
        """
        Calculate normalized Levenshtein distance.
        Returns similarity score between 0-1 (1 is most similar).
        """
        # Create matrix
        n, m = len(seq1), len(seq2)
        if n == 0 or m == 0:
            return 0.0 if max(n, m) > 0 else 1.0
            
        d = np.zeros((n+1, m+1), dtype=int)
        
        # Initialize first row and column
        for i in range(n+1):
            d[i, 0] = i
        for j in range(m+1):
            d[0, j] = j
            
        # Fill the matrix
        for j in range(1, m+1):
            for i in range(1, n+1):
                if seq1[i-1] == seq2[j-1]:
                    d[i, j] = d[i-1, j-1]  # No operation
                else:
                    d[i, j] = min(
                        d[i-1, j] + 1,      # deletion
                        d[i, j-1] + 1,      # insertion
                        d[i-1, j-1] + 1     # substitution
                    )
        
        # Normalize (0-1 range where 1 is perfect match)
        max_distance = max(n, m)
        similarity = 1.0 - d[n, m] / max_distance if max_distance > 0 else 1.0
        return similarity
    
    def _calculate_lcs(self, seq1: List[int], seq2: List[int]) -> float:
        """
        Calculate normalized Longest Common Subsequence.
        Returns similarity score between 0-1 (1 is most similar).
        """
        n, m = len(seq1), len(seq2)
        if n == 0 or m == 0:
            return 0.0
            
        # Create matrix
        lcs = np.zeros((n+1, m+1), dtype=int)
        
        # Fill the matrix
        for i in range(1, n+1):
            for j in range(1, m+1):
                if seq1[i-1] == seq2[j-1]:
                    lcs[i, j] = lcs[i-1, j-1] + 1
                else:
                    lcs[i, j] = max(lcs[i-1, j], lcs[i, j-1])
        
        # Normalize (0-1 range where 1 is perfect match)
        # Length of LCS divided by length of longer sequence
        similarity = lcs[n, m] / max(n, m)
        return similarity
    
    def _calculate_cosine_similarity(self, seq1: List[int], seq2: List[int]) -> float:
        """
        Calculate cosine similarity between two sequences.
        Returns similarity score between 0-1 (1 is most similar).
        """
        # Handle empty sequences
        if not seq1 or not seq2:
            return 0.0
            
        # Convert to numpy arrays
        arr1 = np.array(seq1)
        arr2 = np.array(seq2)
        
        # Make them the same length by padding the shorter one
        max_len = max(len(arr1), len(arr2))
        if len(arr1) < max_len:
            arr1 = np.pad(arr1, (0, max_len - len(arr1)), 'constant')
        elif len(arr2) < max_len:
            arr2 = np.pad(arr2, (0, max_len - len(arr2)), 'constant')
        
        # Calculate cosine similarity
        dot_product = np.dot(arr1, arr2)
        norm1 = np.linalg.norm(arr1)
        norm2 = np.linalg.norm(arr2)
        
        # Avoid division by zero
        if norm1 == 0 or norm2 == 0:
            return 0.0
            
        similarity = dot_product / (norm1 * norm2)
        return max(0.0, min(1.0, similarity))  # Clamp to [0, 1]
    
    def _calculate_pitch_accuracy(self, seq1: List[int], seq2: List[int]) -> float:
        """
        Calculate the pitch accuracy (percentage of matching notes).
        """
        # Handle empty sequences
        if not seq1 or not seq2:
            return 0.0
            
        # Make sequences the same length for comparison
        max_len = max(len(seq1), len(seq2))
        min_len = min(len(seq1), len(seq2))
        
        # Count matching notes
        matches = sum(1 for i in range(min_len) if seq1[i] == seq2[i])
        
        # Perfect match for overlapping part, penalty for length difference
        if min_len == max_len:
            return matches / max_len
        else:
            # Apply a penalty for length mismatch
            length_penalty = min_len / max_len
            return (matches / min_len) * length_penalty
    
    def _create_note_details(self, target_melody: List[int], played_melody: List[int]) -> List[Dict[str, Any]]:
        """
        Create detailed note-by-note comparison.
        """
        details = []
        max_len = max(len(target_melody), len(played_melody))
        
        for i in range(max_len):
            detail = {"index": i}
            
            # Add target note if exists
            if i < len(target_melody):
                target_note = target_melody[i]
                detail["target_note"] = target_note
                detail["target_note_name"] = self._note_to_name(target_note)
            
            # Add played note if exists
            if i < len(played_melody):
                played_note = played_melody[i]
                detail["played_note"] = played_note
                detail["played_note_name"] = self._note_to_name(played_note)
            
            # Check if notes match
            if i < len(target_melody) and i < len(played_melody):
                detail["is_correct_pitch"] = target_melody[i] == played_melody[i]
                
                # Mock timing data (for demonstration)
                # In a real implementation, you would use actual timing data
                detail["onset_error"] = np.random.randint(0, 200)
                detail["duration_error"] = np.random.randint(0, 100)
                detail["target_onset"] = i * 500
                detail["played_onset"] = i * 500 + detail["onset_error"]
                detail["target_duration"] = 450
                detail["played_duration"] = 450 - detail["duration_error"]
            
            details.append(detail)
        
        return details
        
    def _note_to_name(self, midi_note: int) -> str:
        """
        Convert MIDI note number to note name (e.g., 60 -> C4).
        """
        note_names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        octave = (midi_note // 12) - 1
        note_idx = midi_note % 12
        return f"{note_names[note_idx]}{octave}" 