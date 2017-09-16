

```python
from bokeh.plotting import figure, output_file, show
output_file("../../figures/glyph-circle.html")

p = figure()

p.circle(x=range(5),y=range(5))
show(p)
```


```python

```
