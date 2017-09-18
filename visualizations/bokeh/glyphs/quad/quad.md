
# Bokeh Quad Glyph


```python
from bokeh.plotting import figure, output_file, show
from bokeh.models import Range1d
from bokeh.io import export_png

fill_colors = ['#80b1d3','#8dd3c7','#ffffb3','#bebada']
line_colors = ['#fb8072','#80b1d3','#b3de69','#bc80bd']
output_file("../../figures/quad.html")

p = figure(plot_width=400, plot_height=400)
p.quad(left=0,right=0.5,bottom=0,top=0.5, fill_alpha=1,fill_color=fill_colors[0],
         line_alpha=1, line_color=line_colors[0], line_dash='solid', line_width=5)
p.quad(left=0.8,right=1.5,bottom=0.8,top=1.2, fill_alpha=1,fill_color=fill_colors[1],
         line_alpha=1, line_color=line_colors[1], line_dash='solid', line_width=5)
p.quad(left=0.75,right=1.5,bottom=0,top=0.5, fill_alpha=1,fill_color=fill_colors[2],
         line_alpha=1, line_color=line_colors[2], line_dash='solid', line_width=5)
p.quad(left=0,right=0.5,bottom=0.75,top=1.5, fill_alpha=1,fill_color=fill_colors[3],
         line_alpha=1, line_color=line_colors[3], line_dash='solid', line_width=5)
p.x_range = Range1d(-0.25,1.5, bounds=(-1,2))
p.y_range = Range1d(-0.25,1.5, bounds=(-1,2))
show(p)
export_png(p, filename="../../figures/quad.png");
```
