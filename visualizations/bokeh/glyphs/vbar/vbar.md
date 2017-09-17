
# Bokeh Vbar Glyph


```python
from bokeh.plotting import figure, output_file, show
from bokeh.models import Range1d
from math import radians

line_color = '#1f78b4'
fill_color = 'black'
output_file("../../figures/glyph-vbar.html")

p = figure(plot_width=400, plot_height=400)
p.vbar(x=0, bottom=-0.5, top=1.50, width=0.5, fill_alpha=1,fill_color=fill_color,
         line_alpha=1, line_color=line_color, line_dash='solid', line_width=5)
p.vbar(x=1, bottom=-0.5, top=0.5, width=0.75, fill_alpha=0.8, fill_color=fill_color, 
         line_alpha=1, line_color=line_color, line_dash='dotdash', line_width=8)
p.x_range = Range1d(-0.5,1.5, bounds=(-1,2))
p.y_range = Range1d(-0.5,1.5, bounds=(-1,2))
show(p)
```
