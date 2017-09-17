
# Bokeh Cross Glyph


```python
from bokeh.plotting import figure, output_file, show
from bokeh.models import Range1d
from math import radians

line_color = '#2166ac'
output_file("../../figures/glyph-cross.html")

p = figure(plot_width=400, plot_height=400)
p.cross(x=0,y=0,size=100, fill_alpha=1,fill_color=fill_color, angle=radians(0),
         line_alpha=1, line_color=line_color, line_dash='dashed', line_width=5)
p.cross(x=0,y=1,size=100, fill_alpha=0.8, fill_color=fill_color, angle=radians(25),
         line_alpha=1, line_color=line_color, line_dash='dotdash', line_width=8)
p.cross(x=1,y=0,size=100, fill_alpha=0.6, fill_color = fill_color, angle=radians(45),
         line_alpha=1, line_color=line_color, line_dash='dotted', line_width=13)
p.cross(x=1,y=1,size=100, fill_alpha=0.4, fill_color = fill_color, angle=radians(75),
         line_alpha=1, line_color=line_color, line_dash='solid', line_width=17)
p.x_range = Range1d(-0.5,1.5, bounds=(-1,2))
p.y_range = Range1d(-0.5,1.5, bounds=(-1,2))
show(p)
```
