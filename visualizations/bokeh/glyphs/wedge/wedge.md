
# Bokeh Wedge Glyph


```python
from bokeh.plotting import figure, output_file, show
from bokeh.models import Range1d
from math import radians
from bokeh.io import export_png

fill_color = '#feb24c'
line_color = '#f03b20'
output_file("../../figures/wedge.html")

p = figure(plot_width=400, plot_height=400)
p.wedge(radius=0.1, start_angle=0, end_angle=radians(360),
                x=0,y=0, fill_alpha=1,fill_color=fill_color, direction='clock',
                line_alpha=1, line_color=line_color, line_dash='dashed', line_width=5)
p.wedge(radius=0.2, start_angle=0, end_angle=radians(270),
                x=0,y=1, fill_alpha=1,fill_color=fill_color, direction='clock',
                line_alpha=1, line_color=line_color, line_dash='dotdash', line_width=5)
p.wedge(radius=0.1,  start_angle=0, end_angle=radians(360),
                x=1,y=0, fill_alpha=1,fill_color=fill_color, direction='anticlock',
                line_alpha=1, line_color=line_color, line_dash='dotted', line_width=5)
p.wedge(radius=0.35, start_angle=0, end_angle=radians(270),
                x=1,y=1, fill_alpha=1,fill_color=fill_color, direction='anticlock',
                line_alpha=1, line_color=line_color, line_dash='solid', line_width=5)
p.x_range = Range1d(-0.5,1.5, bounds=(-1,2))
p.y_range = Range1d(-0.5,1.5, bounds=(-1,2))
show(p)
export_png(p, filename="../../figures/wedge.png");
```
