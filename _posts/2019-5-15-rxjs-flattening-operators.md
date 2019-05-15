---
layout: post
title: Demystifying Flattening Operators in RXJS without Code
subtitle: What's the difference in switchMap, concatMap, mergeMap, and exhaustMap?
---

Like it or not, `rxjs` is a critical component of modern Angular development. Although it is perfectly possible to use Angular 2+ without using observables, you lose out on an enormous amount of functionality. The reactive pattern is extremely powerful, and once you get over the, admittedly rather high, learning curve the grass is definitely greener on the other side.

One of the most confusing concepts in `rxjs` are the flattening operators. If you are new to `rxjs` and Angular, you have probably slogged through head-spinning documentation like "The observable subscribes to a source observable and transforms all observables into an infinite hypergeometric series of observables, collecting all emissions in a central location until the mass hits a critical point, collapses into a black hole, at which point traces of Hawking emission are emitted as an inner observable, but only if it is a day of the week that begins with T".

That's what it feels like at least.

In reality, the flattening operators `switchMap`, `concatMap`, `mergeMap`, and `exhaustMap` are very simple. Like all pipeable operators, they begin with a source observable that is emitting values. The difference with the flattening operators is that each emitted value from the source observable is mapped to _another observable_. Contrast this with `map`, which just takes one value in and emits a new value (not another observable). The inner observable is then "lifted" up into the primary pipeline, so what comes out of the other side of a flattening operator is always the inner observable.

If there is only one value emitted from the source or there is a long time between emissions so that the inner calculation completes before there is a new value from the source observable, there is _no_ difference in how the flattening operators behave. The key difference is how they behave when there are multiple overlapping emissions from the source, which means you simultaneously have created multiple inner observables.

### An analogy

Pretend that the source observable is your boss, and you are the flattening operator. Each time your boss gives you some work (source emits a new value), you begin to work on a new task (creating a new inner observable). If you are still in the middle of one task and your boss gives you something else to do, how do you handle the situation?

- `switchMap` - Drop everything you were already doing and immediately begin the new task. This means only the latest and greatest values are provided.

- `concatMap` - You add your boss's request to the end of your to-do list, but you completely finish whatever you were currently working on, and then you begin work on the next task. You eventually finish everything, and you do so in order.

- `mergeMap` - The overachieving multitasker. You immediately begin working on everything your boss gives you as soon as he/she assigns it.

- `exhaustMap` - You have tunnel vision and completely ignore new requests from your boss until you are done with what you are working on, and only then do you begin listening for new tasks.

### Use cases

In real-world development, when might you use each of these?

- `switchMap` - This is commonly used with HTTP requests where a new source emission means you no longer care about or need the previous inflight request. The current inner observable is canceled and only the new one is active.

- `concatMap` - Use this when the order of operations is important such as if you were calculating updates to a financial transaction where you needed to add money and add an interest payment, in which case the order that the addition and multiplication happen matters and transactions occur in order.

- `mergeMap` - This is like drinking from a firehose -- use this when you don't care about the order of operations and just want all of the things to happen ASAP, such as an alert system.

- `exhaustMap` - A common use-case here is login requests; usually there is no reason to send another authentication request until you have received the status of the first, so if the user types in their credentials and spammed the login button you would only send the first login request and not send another until it returns with success or failure. Yes, you would normally disable the login button during the request, but that is a separate concern to how this operator works.

I hope this helps make things more clear. Happy (reactive) programming!
