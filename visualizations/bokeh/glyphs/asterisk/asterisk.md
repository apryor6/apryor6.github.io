
# Bokeh Asterisk Glyph


```python
from bokeh.plotting import figure, output_file, show
from bokeh.models import Range1d
from math import radians

line_color = '#91bfdb'
output_file("../../figures/glyph-asterisk.html")

p = figure(plot_width=400, plot_height=400)
p.asterisk(x=0,y=0,size=100,line_alpha=1,
           line_color=line_color, line_dash='dashed', line_width=5)
p.asterisk(x=0,y=1,size=100,line_alpha=1,
           line_color=line_color, line_dash='dotdash', line_width=8)
p.asterisk(x=1,y=0,size=100, line_alpha=1,
           line_color=line_color, line_dash='dotted', line_width=13)
p.asterisk(x=1,y=1,size=100, line_alpha=1,
           line_color=line_color, line_dash='solid', line_width=17)
p.x_range = Range1d(-0.5,1.5, bounds=(-1,2))
p.y_range = Range1d(-0.5,1.5, bounds=(-1,2))
show(p)
```
