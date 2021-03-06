
# Bokeh Arc Glyph


```python
from bokeh.plotting import figure, output_file, show
from bokeh.models import Range1d
from math import radians
from bokeh.io import export_png

line_color = 'black'
output_file("../../figures/arc.html")

p = figure(plot_width=400, plot_height=400)
p.arc(radius=0.1, start_angle=0, end_angle=radians(360),
                x=0,y=0, direction='clock',
                line_alpha=1, line_color=line_color, line_dash='dashed', line_width=5)
p.arc(radius=0.2, start_angle=0, end_angle=radians(270),
                x=0,y=1, direction='clock',
                line_alpha=1, line_color=line_color, line_dash='dotdash', line_width=5)
p.arc(radius=0.1, start_angle=0, end_angle=radians(360),
                x=1,y=0, direction='anticlock',
                line_alpha=1, line_color=line_color, line_dash='dotted', line_width=5)
p.arc(radius=0.35, start_angle=0, end_angle=radians(270),
                x=1,y=1, direction='anticlock',
                line_alpha=1, line_color=line_color, line_dash='solid', line_width=5)
p.x_range = Range1d(-0.5,1.5, bounds=(-1,2))
p.y_range = Range1d(-0.5,1.5, bounds=(-1,2))
show(p)
export_png(p, filename="../../figures/arc.png");
```
