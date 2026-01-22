import pytest
from app import create_app


@pytest.fixture
def client():
    app = create_app("testing")
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client


def test_index_route(client):
    """Test the root endpoint returns welcome message."""
    response = client.get("/")
    assert response.status_code == 200
    assert b"Welcome to the Titanic API" in response.data


def test_health_check(client):
    """Test the app is running."""
    response = client.get("/")
    assert response.status_code == 200
