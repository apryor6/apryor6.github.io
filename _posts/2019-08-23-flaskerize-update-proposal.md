---
layout: post
title: Forward-migratability over backwards compatibility - a proposal for update schematics in Python
subtitle: Moving towards seamless updates across breaking APIs
tags:
  [
    flask,
    python,
    backend development,
    flaskerize,
    angular cli,
    schematics,
    api,
    data science,
    software engineering,
  ]
---

An incredibly useful feature of the Angular CLI is [ng-update](https://angular.io/cli/update), which provides a modification schematic for rewriting broken APIs as you upgrade across version of a library. The mechanism by which it works is that third party libraries provide a schematic with a special name, and then the `ng-update` command looks into the project for that schematic and executes it.

I'm working on a Python project called [flaskerize](https://github.com/apryor6/flaskerize) that could, among other things, implement this functionality. We could easily implement such a hook in flaskerize like fz update <package_name> that would really be just an alias for fz generate <package_name:fz_update> or something similar (here I have implicitly proposed that fz_update be the default schematic name.. doesn't need to be).. See this [ issue](https://github.com/apryor6/flaskerize/issues/20) for tracking updates.

The implications of this functionality would be profound. If these update schematics were incorporated into `pip upgrade`, it would be possible for library authors to relentlessly make breaking changes in their libraries without any concern for backwards compatibility provided that there was a schematic-upgrade path to migrate across versions. Enormous time and resources could be saved that are currently spent on managing long-term deprecation cycles as outdated parameters and APIs are moved. Instead, we would be moving towards a philosophy of _forward-compatibility_. This also puts the mental burden of bridging from an old library API to a new one on the library developers first and the consumers second, rather than the other way around.

I'm happy to hear thoughts on this [on twitter](https://twitter.com/pryor_aj) or you can email me apryor6@gmail.com
