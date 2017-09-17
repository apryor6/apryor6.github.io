
# Bokeh Hbar Glyph


```python
from bokeh.plotting import figure, output_file, show
from bokeh.models import Range1d
from math import radians

fill_color = '#1f78b4'
line_color = 'black'
output_file("../../figures/glyph-hbar.html")

p = figure(plot_width=400, plot_height=400)
p.hbar(y=0, left=-0.5, right=1.50, height=0.5, fill_alpha=1,fill_color=fill_color,
         line_alpha=1, line_color=line_color, line_dash='solid', line_width=5)
p.hbar(y=1, left=-0.5, right=0.5, height=0.75, fill_alpha=0.8, fill_color=fill_color, 
         line_alpha=1, line_color=line_color, line_dash='dotdash', line_width=8)
p.x_range = Range1d(-0.5,1.5, bounds=(-1,2))
p.y_range = Range1d(-0.5,1.5, bounds=(-1,2))
show(p)
```
