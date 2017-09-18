
# Bokeh Quadratic Glyph


```python
from bokeh.plotting import figure, output_file, show
from bokeh.models import Range1d, ColumnDataSource
from bokeh.io import export_png

line_color = 'firebrick'
output_file("../../figures/quadratic.html")
source = ColumnDataSource(dict(
x0 = [0,0,1,1],
y0 = [0,0,1,1],
x1 = [0,1,0,1],
y1 = [0,0,1,1],
cx = [0,0,1,1],
cy = [0,1,0,1]
))
p = figure(plot_width=400, plot_height=400)
p.quadratic(x0='x0',y0='y0',x1='x1',y1='y1', cx='cx',cy='cy', source=source,
         line_alpha=1, line_color=line_color, line_dash='solid', line_width=5)
p.x_range = Range1d(-0.25,1.35, bounds=(-1,2))
p.y_range = Range1d(-0.25,1.35, bounds=(-1,2))
show(p)
export_png(p, filename="../../figures/quadratic.png");
```
