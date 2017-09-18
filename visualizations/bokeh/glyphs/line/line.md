
# Bokeh Line Glyph


```python
from bokeh.plotting import figure, output_file, show
from bokeh.models import Range1d
from bokeh.io import export_png

line_colors = ['#e41a1c','#377eb8','#4daf4a','#984ea3']
output_file("../../figures/line.html")

p = figure(plot_width=400, plot_height=400)
p.line(x=[0, 1],y=[0, .5],
         line_alpha=1, line_color=line_colors[0], line_dash='solid', line_width=10)
p.line(x=[0, 1],y=[0.25, 0.75],
         line_alpha=1, line_color=line_colors[1], line_dash='dotdash', line_width=10)
p.line(x=[0, 1],y=[0.5, 1],
         line_alpha=1, line_color=line_colors[2], line_dash='dashed', line_width=10)
p.line(x=[0, 1],y=[0.75, 1.25],
         line_alpha=1, line_color=line_colors[3], line_dash='dotted', line_width=10)
p.x_range = Range1d(-0.25,1.2, bounds=(-1,2))
p.y_range = Range1d(-0.25,1.2, bounds=(-1,2))
show(p)
export_png(p, filename="../../figures/line.png");
```
