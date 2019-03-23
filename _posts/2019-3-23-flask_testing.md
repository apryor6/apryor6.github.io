---
layout: post
title: Simplified Flask + SQLAlchemy Testing with Pytest Fixtures
subtitle: Writing better tests with less code
---

I _love_ writing tests, mostly because I love refactoring, and testing makes me feel good about refactoring. However, testing web applications can be particularly hard because there is usually a lot more going on than in a math library where a test just means verifying that your `add` function correctly reproduces `1 + 1 = 2`. Web apps have moving parts like database connections, servers, authentication, and request contexts. To further complicate matters, these components must work together with human input, and about the only thing predictable about user input is that if there is a way to break the app, a user will find it.

Recently, I've been writing a lot of Jasmine tests for Angular apps based in rxjs and ngrx (Redux), and I've found that mindset has bled over into my Python development as well. Something about the flow of setup/teardown with test fixtures resonates with me, and so it should be no surprise that I am a big fan of `pytest` when it comes to unit testing in Python. However, there is a bit of a split in the Flask community, as the official documentation [recommends pytest](http://flask.pocoo.org/docs/1.0/testing/), while the very popular [flask-testing](https://pythonhosted.org/Flask-Testing/) project favors `unittest` style tests with classes. I spent some time digging into the various ways to test Flask applications and have settled on a system that I like quite a bit and am now sharing with you.

_The full code for this example project can be found on Github [here](https://github.com/apryor6/flask_testing_examples)_

```python
import pytest

from demo import create_app


@pytest.fixture
def app():
    return create_app('test')


@pytest.fixture
def client(app):
    return app.test_client()


@pytest.fixture
def db(app):
    from demo import db
    with app.app_context():
        db.create_all()
        yield db
        db.drop_all()
        db.session.commit()

```

```python
from demo.tests.fixtures import app


def test_app_creates(app):
    assert app
```
