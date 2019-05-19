---
layout: post
title: Flask best practices
subtitle: Patterns for building testable, scalable, and maintainable APIs
---

I love Flask. It is simple and unopinionated. A consequence of this is that as you look to scale your Flask applications, there are an infinite number of ways you could choose to structure your application. Although there will always be a subset of developers who want to tinker with new design patterns outside of what is considered "standard", by and large my experience is that developers want to focus more on _what_ they are building and less on _how_ they need to build it. The lack of a well-formed application structure simply adds technical debt to the developer's brain, and this housekeeping need takes away from his/her ability to create features. Therefore, I have become increasingly in favor of being opinionated about application design.

After much trial-and-error, I have come up with a set of patterns that work really well, allowing you to build highly modular and scalable Flask APIs. This pattern has been battle-tested (double emphasis on the word "test"!) and works well for a big project with a large team and can easily scale to a project of any size. Although the design is tech-stack agnostic, throughout this project I use the following technologies:
		- `pytest``, for testing
		- Marshamllow for data serialization/deserialization and schema validation
		- SQLAlchemy as an ORM
		- Flast-RESTplus for Swagger documentation
		- `flask_accepts`, a library I wrote that marries Marshmallow with Flask-RESTplus, giving you the control of marshmallow with the awesome Swagger documentation from flask-RESTplus.

For the rest of this post I will walk through the system and will explain my opinions as if they are facts. Keep in mind that my opinions are, well, opinions. However, also keep in mind that this is a topic that I have spent a _lot_ of time thinking about and even more time implementing in the real world; therefore, I think there is a lot of truth here. I am certainly open to debate/feedback.

### High-level overview

Application code should be grouped such that files related to the same topic are localized, and _not_ such that code that is functionally similar is localized. This means you should have a folder for `widgets/` that contains the services, type-definitions, etc for `widgets/`, and you should NOT have a `services/` folder where you keep all of your services. Always ask yourself:

> If my boss asked me to delete all of the code for feature `foo`, how hard would that be?

If you are more bullish on your features and cannot imagine a world where your boss would ever want you to delete anything, feel free to change the question to:

> When <insert Fortune 500 company> inevitably acquires my startup, how easy will it be for me to copy/paste modules into their monorepo?

If the answer to either of these questions is "Not very long, because I just need to grab the `foo/` folder and update one or two configurations", then you are probably doing thing correctly.

The problem with having a `services/`, `tests/`, `controllers/` folder is that when your project scales it becomes cumbersome to sift through each of these large folders to find the code that you are working on. As the project continues to grow, this problem gets worse. Conversely, if I have a `widgets/` folder where I can find a `service.py`, `controller.py`, `model.py`, etc and all of the associated tests, everything is there in one place.