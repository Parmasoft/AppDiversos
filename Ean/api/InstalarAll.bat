cd C:\Parmasoft\app_scanner\api
python -m venv venv
venv\Scripts\activate
python -m pip install --upgrade pip setuptools wheel
pip install flask fdb flask-cors python-dotenv requests
python -c "import flask; print('Flask OK')"
python -c "import fdb; print('FDB OK')"
python -c "import flask_cors; print('Flask-CORS OK')"
python app.py