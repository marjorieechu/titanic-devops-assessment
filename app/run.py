import os

from app import create_app

if __name__ == '__main__':
    env_name = os.getenv('FLASK_ENV', default='development')
    application = create_app(env_name)

    application.run(host='0.0.0.0', port=5000)
