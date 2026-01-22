import pytest

from app import create_app


@pytest.fixture
def client():
    flask_app = create_app("testing")
    flask_app.config["TESTING"] = True
    with flask_app.test_client() as test_client:
        yield test_client


def test_index_route(client):
    """Test the root endpoint returns welcome message."""
    response = client.get("/")
    assert response.status_code == 200
    assert b"Welcome to the Titanic API" in response.data


def test_health_check(client):
    """Test the app is running."""
    response = client.get("/")
    assert response.status_code == 200
