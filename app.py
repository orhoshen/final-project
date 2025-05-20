from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
from dotenv import load_dotenv
import os
import numpy as np
from algorithms.melody_matcher import MelodyMatcher

# Load environment variables
load_dotenv()

# Initialize Flask app
app = Flask(__name__, static_folder='static')
CORS(app)  # Enable CORS for all routes

# Initialize melody matcher
melody_matcher = MelodyMatcher()

# Configuration
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'your-secret-key-here')

@app.route('/')
def home():
    return jsonify({
        'message': 'Welcome to the Flask Server!',
        'status': 'running'
    })

@app.route('/api/health')
def health_check():
    return jsonify({
        'status': 'healthy',
        'version': '1.0.0'
    })

@app.route('/api/compare-melodies', methods=['POST'])
def compare_melodies():
    try:
        data = request.get_json()
        
        if not data or 'melody1' not in data or 'melody2' not in data:
            return jsonify({
                'error': 'Missing required fields: melody1 and melody2'
            }), 400

        melody1 = data['melody1']
        melody2 = data['melody2']

        # Validate input
        if not isinstance(melody1, list) or not isinstance(melody2, list):
            return jsonify({
                'error': 'Melodies must be lists of integers'
            }), 400

        # Compare melodies
        result = melody_matcher.compare_melodies(melody1, melody2)
        
        return jsonify({
            'success': True,
            'result': result
        })

    except Exception as e:
        return jsonify({
            'error': str(e)
        }), 500

@app.route('/api/estimate-difficulty', methods=['POST'])
def estimate_difficulty():
    try:
        data = request.get_json()
        
        if not data or 'melody' not in data:
            return jsonify({
                'error': 'Missing required field: melody'
            }), 400

        melody = data['melody']

        # Validate input
        if not isinstance(melody, list):
            return jsonify({
                'error': 'Melody must be a list of integers'
            }), 400
        
        if len(melody) < 1:
            return jsonify({
                'error': 'Melody must contain at least one note'
            }), 400

        # Calculate difficulty factors
        difficulty_score = calculate_difficulty(melody)
        
        return jsonify({
            'success': True,
            'result': difficulty_score
        })

    except Exception as e:
        return jsonify({
            'error': str(e)
        }), 500

def calculate_difficulty(melody):
    """Calculate the difficulty score of a melody based on multiple factors"""
    try:
        # Convert to numpy array for easier calculations
        melody_array = np.array(melody)
        
        # Factor 1: Length - longer melodies are harder
        length_factor = min(len(melody) / 4, 3)  # Up to 3 points for length
        
        # Factor 2: Range - wider range is harder
        note_range = np.max(melody_array) - np.min(melody_array)
        range_factor = min(note_range / 12, 3)  # Up to 3 points per octave
        
        # Factor 3: Intervals - larger jumps between consecutive notes are harder
        if len(melody) > 1:
            intervals = np.abs(np.diff(melody_array))
            avg_interval = np.mean(intervals)
            max_interval = np.max(intervals)
            interval_factor = min(avg_interval / 2 + max_interval / 12, 3)
        else:
            interval_factor = 0
            
        # Factor 4: Repetition - less repetition is harder
        unique_notes = len(np.unique(melody_array))
        repetition_factor = min(unique_notes / len(melody), 1) * 2  # Up to 2 points
            
        # Calculate final score (base of 1 + factors)
        difficulty_score = 1 + length_factor + range_factor + interval_factor + repetition_factor
        
        # Clamp to 1-10 range
        difficulty_score = max(1, min(10, difficulty_score))
        
        return {
            'difficulty_score': difficulty_score,
            'factors': {
                'length': length_factor,
                'range': range_factor,
                'intervals': interval_factor,
                'repetition': repetition_factor
            }
        }
    except Exception as e:
        # Fallback to simple length-based difficulty
        return {
            'difficulty_score': min(1 + len(melody) / 3, 10),
            'factors': {
                'length': min(len(melody) / 3, 3),
                'error': str(e)
            }
        }

# Soundfont file serving endpoints
@app.route('/api/soundfonts/<path:filename>')
def serve_soundfont(filename):
    """Serve soundfont files"""
    return send_from_directory('static/soundfonts', filename)

@app.route('/api/piano_notes/<path:filename>')
def serve_piano_note(filename):
    """Serve individual piano note files"""
    return send_from_directory('static/piano_notes', filename)

@app.route('/api/soundfonts')
def list_soundfonts():
    """List available soundfont files"""
    try:
        files = os.listdir('static/soundfonts')
        files = [f for f in files if f.endswith('.sf2')]
        
        return jsonify({
            'success': True,
            'soundfonts': files
        })
    except Exception as e:
        return jsonify({
            'error': str(e)
        }), 500

@app.route('/api/piano_notes')
def list_piano_notes():
    """List available piano note files"""
    try:
        files = os.listdir('static/piano_notes')
        files = [f for f in files if f.endswith('.mp3')]
        
        return jsonify({
            'success': True,
            'notes': files
        })
    except Exception as e:
        return jsonify({
            'error': str(e)
        }), 500

@app.route('/static/<path:filename>')
def serve_static(filename):
    """Serve static files"""
    return send_from_directory('static', filename)

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5001))
    app.run(host='0.0.0.0', port=port, debug=True) 