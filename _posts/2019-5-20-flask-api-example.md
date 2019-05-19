---
layout: post
title: Flask best practices
subtitle: Patterns for building testable, scalable, and maintainable APIs
---

I love Flask. It is simple and unopinionated. A consequence of this is that as you look to scale your Flask applications, there are an infinite number of ways you could choose to structure your application. Although there will always be a subset of developers who want to tinker with new design patterns outside of what is considered "standard", by and large my experience is that developers want to focus more on _what_ they are building and less on _how_ they need to build it. The lack of a well-formed application structure simply adds technical debt to the developer's brain, and this housekeeping need takes away from his/her ability to create features. Therefore, I have become increasingly in favor of being opinionated about application design.

_I have created a full sample project with this pattern that you can find [here](https://github.com/apryor6/flask_api_example). This includes an API with 1) multiple, modular namespaces within the same RESTplus API, 2) a standalone RESTplus API attached to a blueprint with its own Swagger documentation, and 3) A third-party/installable blueprint-based API demonstrating how you might share a modular API across apps, such as if your organization has a core API that you want to reuse._

After much trial-and-error, I have come up with a set of patterns that work really well, allowing you to build highly modular and scalable Flask APIs. This pattern has been battle-tested (double emphasis on the word "test"!) and works well for a big project with a large team and can easily scale to a project of any size. Although the design is tech-stack agnostic, throughout this project I use the following technologies:
		- `Flask` (d'oh)
		- `pytest`, for testing
		- Marshmallow for data serialization/deserialization and input validation
		- SQLAlchemy as an ORM
		- Flast-RESTplus for Swagger documentation
		- [`flask_accepts`](https://github.com/apryor6/flask_accepts), a library I wrote that marries Marshmallow with Flask-RESTplus, giving you the control of marshmallow with the awesome Swagger documentation from flask-RESTplus.

In a nutshell, Flask requests are routed using RESTplus Resources, input data is validated with a Marshmallow schema, some data processing occurs via a service interacting with a model, and then the output is serialized back to JSON on the way out, again using Marshmallow. All of this is documented via interactive Swagger docs, and [`flask_accepts`](https://github.com/apryor6/flask_accepts) serves as glue that under-the-hood maps each Marshmallow schema into an equivalent Flask-RESTplus API model so that these two amazing-but-somewhat-incompatible technologies can happily be used together.

For the rest of this post I will walk through the system and will explain my opinions as if they are facts. Keep in mind that my opinions are, well, opinions. However, also keep in mind that this is a topic that I have spent a _lot_ of time thinking about and even more time implementing in the real world; therefore, I think there is a lot of truth here. I am certainly open to debate/feedback.

### High-level overview

Application code should be grouped such that files related to the same topic are localized, and _not_ such that code that is functionally similar is localized. This means you should have a folder for `widgets/` that contains the services, type-definitions, etc for `widgets/`, and you should NOT have a `services/` folder where you keep all of your services. Always ask yourself:

> If my boss asked me to delete all of the code for feature `foo`, how hard would that be?

If you are more bullish on your features and cannot imagine a world where your boss would ever want you to delete anything, feel free to change the question to:

> When <insert Fortune 500 company> inevitably acquires my startup, how easy will it be for me to copy/paste modules into their monorepo?

If the answer to either of these questions is "Not very long, because I just need to grab the `foo/` folder and update one or two configurations", then you are probably doing thing correctly.

The problem with having a `services/`, `tests/`, `controllers/` folder is that when your project scales it becomes cumbersome to sift through each of these large folders to find the code that you are working on. As the project continues to grow, this problem gets worse. Conversely, if I have a `widgets/` folder where I can find a `service.py`, `controller.py`, `model.py`, etc and all of the associated tests, everything is there in one place.

### Terminology

The basic unit of an API is called an entity. An entity is a thing that you want to be able to get, create, update, or edit (REST). An entity might have an underlying database table, but it does not necessarily. It could also be a derived join of several tables, data fetched from a third-party API, predictions from a machine learning model, etc.

An entity consists of (at least) the following pieces:

	- Model: Python representation of entities
	- Interface: Defines types that make an entity
	- Controller: Orchestrates routes, services, schemas for entites
	- Schema: Serialization/deserialization of entities
	- Service: Performs CRUD and manipulation of entities

Note how each of these pieces is focused on only one thing. If you cannot describe a class in one sentence, it probably should be broken up.

Test files for the entity live in the same folder, and are named identically to the file they test with the addition of `_test` appended to the name (prior to the `.py`)

This means a basic entity contains the following files.

```
├── __init__.py
├── controller.py
├── controller_test.py
├── interface.py
├── interface_test.py
├── model.py
├── model_test.py
├── schema.py
├── schema_test.py
├── service.py
└── service_test.py
```

In practice, I often do not have a `schema_test` or `interface_test` because these files are purely Marshmallow schemas and python types, respectively, and thus testing them would be equivalent to testing code from another project, which you should never do.

### Model
The model is where the entity itself is defined in a Python representation. If you are using SQLAlchemy, this will be a class that inherits from `db.Model`. However, the model does not necessarily need to be an object from an ORM with an underlying database table; it just needs to be a python representation of a thing regardless of how you create a thing. An example:

```python
class Widget(db.Model):  # type: ignore
    '''A snazzy Widget'''

    __tablename__ = 'widget'

    widget_id = Column(Integer(), primary_key=True)
    name = Column(String(255))
    purpose = Column(String(255))
```

### Testing models

Minimal testing of a model consists of ensuring that it can be successfully created. This can be done by making a new `widget` as a pytest fixture and asserting that it works. Plenty of other ways to make a similar test, but I like this approach by default because if the model has additional functionality that needs to be tested then you will want a fixture so that you get a clean object for each test.

```python
from pytest import fixture
from .model import Widget

@fixture
def widget() -> Widget:
    return Widget(
        widget_id=1, name='Test widget', purpose='Test purpose'
    )


def test_Widget_create(widget: Widget):
    assert widget
```

### Interface
The interface is a typed definition of what is needed to create an entity. You might ask why there is a separate need for an interface if you have already defined a model, and the reason is twofold. First, the model may be built upon constructs from a third-party library that are not directly typeable. SQLAlchemy is an immediate example: you declare fields in the model that map to underlying database tables, but when I want to construct an entity itself I just need to pass in the types of data that correspond to those underlying columns. Therefore, it makes sense to separately define _what is it_ (model) vs _what makes it_ (interface). In addition, if you want to create an entity using packing/unpacking with `Widget(**params)` syntax, you need to provide a type definition for `params` so that mypy knows what is compatible for the constructor.

Here's a basic example. I have recently moved to defining these with `TypedDict` from `mypy_extensions`. I imagine this will eventually make its way into the Python core library, and there is currently [an open pep](https://www.python.org/dev/peps/pep-0589/) for this. The advantage of `TypedDict` is that it allows you to explicitly declare what the names of the keys are. The inclusion of `total=False` makes all of the parameters optional. You can omit this if you would prefer to always provide all parameters. If you are a TypeScript user, using `total=False` is essentially the same as declaring a `Partial<Widget>`, and it allows you to create a `Widget(**params)` without explicitly providing every parameter, such as when you want to rely on default values. Note, you will still get type errors of you put an invalid type for a key or mistype a key, so there is a lot of benefit all around.

```python
from mypy_extensions import TypedDict


class WidgetInterface(TypedDict, total=False):
    widget_id: int
    name: str
    purpose: str

```

### Testing interfaces

Testing an interface is trivial: verify that it can be constructued and that it can be used to construct it's corresponding model. Nothing interesting here, and I use tools like [flaskerize](https://github.com/apryor6/flaskerize) to generate this kind of code.

```python
from pytest import fixture
from .model import Widget
from .interface import WidgetInterface


@fixture
def interface() -> WidgetInterface:
    return WidgetInterface(
        widget_id=1, name='Test widget', purpose='Test purpose'
    )


def test_WidgetInterface_create(interface: WidgetInterface):
    assert interface


def test_WidgetInterface_works(interface: WidgetInterface):
    widget = Widget(**interface)
    assert widget
```

### Schema
Marshmallow chemas are responsible for handling input/output operations for the API and are where renaming conventions are handled. JavaScript is the language of the web, and in JavaScript the preferred style for variables is lowerCamelCase, whereas in python snake_case is preferred. The schema is the perfect place to handle this translation as it is the layer between your API and the outside world. Marshmallow is an amazing technology that you can learn more about [here](https://marshmallow.readthedocs.io/en/3.0/), and it can do an enormous number of tasks that are much more complicated than the example I give below. For example, you can use the `post_load` hook from Marshmallow to declare what object(s) to create when the `Schema.load` method is invoked, which will automatically synergize with `flask_accepts` to provide a fully-instantiated object in `request.parsed_obj`, for example.

```python
from marshmallow import fields, Schema


class WidgetSchema(Schema):
    '''Widget schema'''

    widgetId = fields.Number(attribute='widget_id')
    name = fields.String(attribute='name')
    purpose = fields.String(attribute='purpose')
```

Here we are saying that the incoming POST request is expected to have (up to) 3 fields with the names `widgetId`, `name`, `purpose`, and that these map to the attributes `widget_id`, `name`, and `purpose` of the serialized result. Note the case-mapping of `widgetId` -> `widget_id`. In this case the `attribute` parameter is redundant for `name` and `purpose` because they are the same in both styles, but I prefer to keep this for consistency (and, again, I am generating this code with [flaskerize](https://github.com/apryor6/flaskerize))

The schema will be associated with a `Resource` in the controller through use of the [`@accepts`](https://github.com/apryor6/flask_accepts/blob/master/flask_accepts/decorators/decorators.py) and [`@responds`](https://github.com/apryor6/flask_accepts/blob/master/flask_accepts/decorators/decorators.py) decorators from [flask_accepts](https://github.com/apryor6/flask_accepts), which declare what format the data should be for input and what the endpoint returns.

### Testing schemas

Schema testing is very similar to interface testing with the wrinkle that we are also verifying that the names are mapped across case-styles correctly. It's important here that you don't write tests that are verifying that Marshmallow works correctly, instead the tests should be checking that _you_ declared the schema properly so that the input payload that you want to provide actually builds an object.

_If I'm being honest, the value of the tests I have here for schemas and interfaces is small, so if you think they are unnecessary then I have no problem with you skipping them. The tests further below for controllers, services, etc, however, are absolutely necessary._

```python
from pytest import fixture

from .model import Widget
from .schema import WidgetSchema
from .interface import WidgetInterface


@fixture
def schema() -> WidgetSchema:
    return WidgetSchema()


def test_WidgetSchema_create(schema: WidgetSchema):
    assert schema


def test_WidgetSchema_works(schema: WidgetSchema):
    params: WidgetInterface = schema.load({
        'widgetId': '123',
        'name': 'Test widget',
        'purpose': 'Test purpose'
    }).data
    widget = Widget(**params)

    assert widget.widget_id == 123
    assert widget.name == 'Test widget'
    assert widget.purpose == 'Test purpose'
```

### Service
The service is responsible for interacting with the entity. This includes managing CRUD (Create, Read, Update, Delete) operations, fetching data via a query, performing some pandas DataFrame manipulation, getting predictions from a machine learning model, hitting an external API, etc. The service should be the meat-and-potatoes of data processing inside of a route. Your services should be kept modular. Services can (and often, should) depend on other services. When you begin to have interservice dependencies you must use dependency injection (DI) or your system will not be maintainable or testable. I will not go into the details of DI in this post, but I will refer you to [Flask-Injector](https://github.com/alecthomas/flask_injector). You could also roll your own simple system by attaching services to the app object at configuration time ([here](https://speakerdeck.com/mitsuhiko/advanced-flask-patterns) is a very nice presentation on this topic).

```python
from app import db
from typing import List
from .model import Widget
from .interface import WidgetInterface


class WidgetService():
    @staticmethod
    def get_all() -> List[Widget]:
        return Widget.query.all()

    @staticmethod
    def get_by_id(widget_id: int) -> Widget:
        return Widget.query.get(widget_id)

    @staticmethod
    def update(widget: Widget, Widget_change_updates: WidgetInterface) -> Widget:
        widget.update(Widget_change_updates)
        db.session.commit()
        return widget

    @staticmethod
    def delete_by_id(widget_id: int) -> List[int]:
        widget = Widget.query.filter(Widget.widget_id == widget_id).first()
        if not widget:
            return []
        db.session.delete(widget)
        db.session.commit()
        return [widget_id]

    @staticmethod
    def create(new_attrs: WidgetInterface) -> Widget:
        new_widget = Widget(
            name=new_attrs['name'],
            purpose=new_attrs['purpose']
        )

        db.session.add(new_widget)
        db.session.commit()

        return new_widget
```

### Testing services


```python

from flask_sqlalchemy import SQLAlchemy
from typing import List
from app.test.fixtures import app, db  # noqa
from .model import Widget
from .service import WidgetService  # noqa
from .interface import WidgetInterface


def test_get_all(db: SQLAlchemy):  # noqa
    yin: Widget = Widget(widget_id=1, name='Yin', purpose='thing 1')
    yang: Widget = Widget(widget_id=2, name='Yang', purpose='thing 2')
    db.session.add(yin)
    db.session.add(yang)
    db.session.commit()

    results: List[Widget] = WidgetService.get_all()

    assert len(results) == 2
    assert yin in results and yang in results


def test_update(db: SQLAlchemy):  # noqa
    yin: Widget = Widget(widget_id=1, name='Yin', purpose='thing 1')

    db.session.add(yin)
    db.session.commit()
    updates: WidgetInterface = dict(name='New Widget name')

    WidgetService.update(yin, updates)

    result: Widget = Widget.query.get(yin.widget_id)
    assert result.name == 'New Widget name'


def test_delete_by_id(db: SQLAlchemy):  # noqa
    yin: Widget = Widget(widget_id=1, name='Yin', purpose='thing 1')
    yang: Widget = Widget(widget_id=2, name='Yang', purpose='thing 2')
    db.session.add(yin)
    db.session.add(yang)
    db.session.commit()

    WidgetService.delete_by_id(1)
    db.session.commit()

    results: List[Widget] = Widget.query.all()

    assert len(results) == 1
    assert yin not in results and yang in results


def test_create(db: SQLAlchemy):  # noqa

    yin: WidgetInterface = dict(name='Fancy new widget', purpose='Fancy new purpose')
    WidgetService.create(yin)
    results: List[Widget] = Widget.query.all()

    assert len(results) == 1

    for k in yin.keys():
        assert getattr(results[0], k) == yin[k]
```

### Controller
The controller is

```python
from flask import request
from flask_accepts import accepts, responds
from flask_restplus import Namespace, Resource
from flask.wrappers import Response
from typing import List

from .schema import WidgetSchema
from .service import WidgetService
from .model import Widget
from .interface import WidgetInterface

api = Namespace('Widget', description='Single namespace, single entity')  # noqa


@api.route('/')
class WidgetResource(Resource):
    '''Widgets'''

    @responds(schema=WidgetSchema, many=True)
    def get(self) -> List[Widget]:
        '''Get all Widgets'''

        return WidgetService.get_all()

    @accepts(schema=WidgetSchema, api=api)
    @responds(schema=WidgetSchema)
    def post(self) -> Widget:
        '''Create a Single Widget'''

        return WidgetService.create(request.parsed_obj)


@api.route('/<int:widgetId>')
@api.param('widgetId', 'Widget database ID')
class WidgetIdResource(Resource):
    @responds(schema=WidgetSchema)
    def get(self, widgetId: int) -> Widget:
        '''Get Single Widget'''

        return WidgetService.get_by_id(widgetId)

    def delete(self, widgetId: int) -> Response:
        '''Delete Single Widget'''
        from flask import jsonify

        id = WidgetService.delete_by_id(widgetId)
        return jsonify(dict(status='Success', id=id))

    @accepts(schema=WidgetSchema, api=api)
    @responds(schema=WidgetSchema)
    def put(self, widgetId: int) -> Widget:
        '''Update Single Widget'''

        changes: WidgetInterface = request.parsed_obj
        Widget = WidgetService.get_by_id(widgetId)
        return WidgetService.update(Widget, changes)

```

### Testing controllers

```python

from unittest.mock import patch
from flask.testing import FlaskClient

from app.test.fixtures import client, app  # noqa
from .service import WidgetService
from .schema import WidgetSchema
from .model import Widget
from .interface import WidgetInterface
from . import BASE_ROUTE


def make_widget(id: int = 123, name: str = 'Test widget',
                purpose: str = 'Test purpose') -> Widget:
    return Widget(
        widget_id=id, name=name, purpose=purpose
    )


class TestWidgetResource:
    @patch.object(WidgetService, 'get_all',
                  lambda: [make_widget(123, name='Test Widget 1'),
                           make_widget(456, name='Test Widget 2')])
    def test_get(self, client: FlaskClient):  # noqa
        with client:
            results = client.get(f'/api/{BASE_ROUTE}',
                                 follow_redirects=True).get_json()
            expected = WidgetSchema(many=True).dump(
                [make_widget(123, name='Test Widget 1'),
                 make_widget(456, name='Test Widget 2')]
            ).data
            for r in results:
                assert r in expected

    @patch.object(WidgetService, 'create',
                  lambda create_request: Widget(**create_request))
    def test_post(self, client: FlaskClient):  # noqa
        with client:

            payload = dict(name='Test widget', purpose='Test purpose')
            result = client.post(f'/api/{BASE_ROUTE}/', json=payload).get_json()
            expected = WidgetSchema().dump(Widget(
                name=payload['name'],
                purpose=payload['purpose'],
            )).data
            assert result == expected


def fake_update(widget: Widget, changes: WidgetInterface) -> Widget:
    # To fake an update, just return a new object
    updated_Widget = Widget(widget_id=widget.widget_id,
                            name=changes['name'],
                            purpose=changes['purpose'])
    return updated_Widget


class TestWidgetIdResource:
    @patch.object(WidgetService, 'get_by_id',
                  lambda id: make_widget(id=id))
    def test_get(self, client: FlaskClient):  # noqa
        with client:
            result = client.get(f'/api/{BASE_ROUTE}/123').get_json()
            expected = make_widget(id=123)
            print(f'result = ', result)
            assert result['widgetId'] == expected.widget_id

    @patch.object(WidgetService, 'delete_by_id',
                  lambda id: id)
    def test_delete(self, client: FlaskClient):  # noqa
        with client:
            result = client.delete(f'/api/{BASE_ROUTE}/123').get_json()
            expected = dict(status='Success', id=123)
            assert result == expected

    @patch.object(WidgetService, 'get_by_id',
                  lambda id: make_widget(id=id))
    @patch.object(WidgetService, 'update', fake_update)
    def test_put(self, client: FlaskClient):  # noqa
        with client:
            result = client.put(f'/api/{BASE_ROUTE}/123',
                                json={'name': 'New Widget',
                                      'purpose': 'New purpose'}).get_json()
            expected = WidgetSchema().dump(
                Widget(widget_id=123, name='New Widget', purpose='New purpose')).data
            assert result == expected

```