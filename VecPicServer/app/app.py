from flask import Flask, request, jsonify
from flask_cors import CORS
import vtracer
import os
from werkzeug.utils import secure_filename

app = Flask(__name__)
CORS(app)  # Enable CORS for iOS app communication


# Configuration
upload_folder = "/Users/awei/PycharmProjects/VecPicServer/temp"
valid_extensions = {'png', 'jpg', 'jpeg'}

app.config['upload_folder'] = upload_folder


@app.route('/vecpic', methods=['POST'])
def process_image():
    try:
        # Validate request
        if 'file' not in request.files:
            return jsonify({'error': 'No file provided'}), 400

        file = request.files['file']
        file_ext = file.filename.split('.')[-1]
        if file.filename == '':
            return jsonify({'error': 'No file selected'}), 400

        if file_ext not in valid_extensions:
            return jsonify({'error': 'Invalid file type.'}), 400

        # Get color mode
        color_mode = request.form.get('colormode')
        original_filename = request.form.get('filename', file.filename)

        # Save uploaded file
        filename = secure_filename(original_filename)
        input_path = os.path.join(app.config['upload_folder'], f"input_{filename}")
        file.save(input_path)

        # Generate output path
        svg_filename = f"{os.path.splitext(filename)[0]}.svg"
        output_path = os.path.join(app.config['upload_folder'], svg_filename)

        # VTracer conversion
        vtracer.convert_image_to_svg_py(
            input_path,
            output_path,
            colormode=color_mode,
            hierarchical='stacked',
            mode='spline',
            filter_speckle=4,
            color_precision=6,
            layer_difference=16,
            corner_threshold=60,
            length_threshold=4.0,
            max_iterations=10,
            splice_threshold=45,
            path_precision=3
        )

        # Read SVG file content
        with open(output_path, 'r', encoding='utf-8') as svg_file:
            svg_content = svg_file.read()

        # Return SVG as text
        return svg_content, 200, {'Content-Type': 'image/svg+xml'}

    except Exception as e:
        return jsonify({'error': f'Processing failed'}), 500


@app.route('/', methods=['GET'])
def index():
    return jsonify({'status': 'OK'}), 200


if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5000)