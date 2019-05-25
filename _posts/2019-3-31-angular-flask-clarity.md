---
layout: post
title: Setting up a FANG monorepo (Flask + Angular + Nx)
subtitle: Building full stack applications with nrwl/nx
tags:
  [
    flask,
    angular,
    angular2,
    nx,
    nrwl,
    monorepo,
    structure,
    project,
    project structure,
  ]
---

# Nx monorepos with the FANG stack

Lately, I have been having a lot of fun building apps using Angular (7, currently) as the front-end with Flask as the backend. In addition, I have found enormous value in the [nrwl/nx](https://github.com/nrwl/nx) project which provides fantastic tooling and support for managing a monorepo of Angular apps. I have also started putting backend Flask apps into these monorepos, which has a long list of benefits, most notably of which is that having the front end and backend code side-by-side _is just so convenient_. If I need to add a data field to an API return, I can seamlessly switch between updating the typescript interface and modifying the API itself without having to leave the same VS Code environment. My productivity has gone up enormously, pull request reviews are easier, integration testing is better.. the list goes on and on. In this post, I'll show you how to setup a project like this using Flask, Angular, and Nx, which I refer to as the FANG stack.

_The source code for this project can be found [here](https://github.com/apryor6/flangular)_

### Setup nx and Angular

```
npm install -g @angular/cli @nrwl/schematics
```

First, create a new workspace with nx. This command only has to be executed once for the entire lifetime of the monorepo.

```
create-nx-workspace fang
```

At this point the workspace is empty. We can add then add the first angular app with

```
ng generate app flangular
```

You will be asked which directory you would like to use for the app, just hit enter to use the (sensible) defaults. You are also prompted for choosing test runners. Personally, I strongly prefer Jasmine and Cypress.
Once you have gone through the prompt, you will now have two items in the `apps/` folder: `flangular` and `flangular-e2e`. A comment on the structure of an nx monorepo, which can be confusing at first. The top level of the workspace contains configuration files that apply to the _entire_ monorepo. Some files feel very familiar, like `package.json`, but others are specific to nx, most notably `nx.json`. Inside of `apps/` are the various applications within your monorepo, and each of these is a mostly-but-not-quite standalone Angular application. The `package.json` file, for instance, does not exist as it has been lifted up to the top of the monorepo.
Also at the top-level is a `libs/` folder, which is where you can place code that is shared across multiple apps. This is one of the most appealing features about using a monorepo. A small config adjustment is needed to unlock this functionality: edit `tsconfig.json` and update `paths` to the the following:

```
    "paths": {
      "@fang/*": ["libs/*"]
    }
```

This will allow us the awesome ability to import shared code in the `libs/` folder using the syntax `import { something } from @fang/some/path`.

### Serving an app

Nx provides a few extensions on top of the already-awesome Angular CLI. To serve an app inside of an nx monorepo, we just have to slightly modify the usual `ng serve` command to `ng serve --project=flangular`. This extra flag is needed to specify which app to serve, which makes sense considering the whole point of a monorepo is that we want to have multiple apps in the same place.

![start](/images/fang/start.png)

## Adding Flask

```
mkdir backends
mkdir backends/flangular
```

I generally like to give the backend app the same name as the frontend for consistency.

Next, we need a new virtual environment:

```
virtualenv -p python3 backends/flangular/flangular-py3
source backends/flangular/flangular-py3/bin/activate
```

Note that the virtual environment is placed within the backend app itself. This is important, because in general you may require different python environments for each backend. Often the virtual environment is called `venv`, but I personally use like including the project name appended with `py3` and `py2` to make it extra clear which project is active and which version of python I am using from my terminal prompt. Remember to add the path to the virtual environment to `.gitignore`.

We then setup a minimal flask app. In general, I strongly prefer and recommend the lazy factory method of creating Flask apps. Usually that should be broken out into the `__init__.py` file of a larger app, but this example is very simple so I will put everything in `app.py`.

```python
from flask import Flask, jsonify


def create_app():
    app = Flask(__name__)

    # Necessary to allow cross origin requests
    CORS(app)
    # Other initialization goes here

    @app.route('/message')
    def health():
        return jsonify('FANG app is online!')
    return app


if __name__ == '__main__':
    app = create_app()
    app.run(debug=True)
```

```
pip install flask
pip install flask-cors
python backends/flangular/app.py
```

Navigate to `http://127.0.0.1:5000/` and you should see the message "FANG online".

### Connecting Angular and Flask

To connect the front and backend, we will make a service that can make HTTP requests to our Flask endpoint and display some data. For generating components within an nx monorepo, I _strongly_ recommend using the Angular console. Usually I am the type of person that prefers the command line in almost every situation, however, the Angular console is so useful that I make an exception. Go to Generate and select component, name it flask-service, and select `flangular` as the project. This will generate a `--dry-run` command so you can see where the files will be generated. It also shows you the actual command that is being executed, so alternatively you could execute the following to setup our service:

```
ng generate @schematics/angular:component flask-service --project=flangular --module=app.module.ts
```

The service itself will contain one method that makes an API request to the Flask app. Here I am hardcoding the URL/port, but in a "real" app you should use environment variables.

```javascript
// flask-service.service.ts

import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

@Injectable({
  providedIn: 'root'
})
export class FlaskService {
  constructor(private http: HttpClient) {}
  getMessage() {
    return <Observable<string>>this.http.get('http://localhost:5000/message');
  }
}
```

In order to be able to inject the `HttpClient`, make sure to add `HttpClientModule` to the imports within `app.module.ts`, otherwise Angular has now way of knowing what to provide.

`ng generate @schematics/angular:service flask-service --project=flangular`

Inside of `app.component.ts` add an property to hold the data and `ngOnInit` method like so:

```javascript
import { Component, OnInit } from '@angular/core';
import { FlaskService } from './flask.service';
import { Observable } from 'rxjs';

@Component({
  selector: 'fang-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.scss']
})
export class AppComponent implements OnInit {
  title = 'flangular';
  message: Observable<string>;

  constructor(private flaskService: FlaskService) {}
  ngOnInit() {
    this.message = this.flaskService.getMessage();
  }
}
```

Note that the `message` property is an observable of the same type as what `flaskService.getMessage` returns. This observable will be unwrapped with the async pipe in the template, which will manage subscriptions for us.

Next, modify the template so we can show the message received from the API:

```html
<div style="text-align:center">
  <h1>Welcome to {{ title }}!</h1>
  <img
    width="300"
    src="https://raw.githubusercontent.com/nrwl/nx/master/nx-logo.png"
  />
</div>
<div *ngIf="(message | async) as message">{{ message }}</div>
<router-outlet></router-outlet>
```

![start](/images/fang/hookedup.png)

Success!
