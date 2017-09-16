
# Bokeh Circle Glyph


```python
from bokeh.plotting import figure, output_file, show
from bokeh.plotting import figure, output_file, show
from bokeh.models import Range1d
output_file("../../figures/glyph-circle.html")
p = figure()
p.circle(x=0,y=0,size=100, fill_alpha=1,fill_color='#fc8d59',
         line_alpha=0.4, line_color='#91bfdb',line_dash='dashed',line_width=3.5)
p.circle(x=0,y=1,size=100, fill_alpha=0.8, fill_color='#fc8d59',
         line_alpha=0.6, line_color='#91bfdb',line_dash='dotdash',line_width=4)
p.circle(x=1,y=0,size=100, fill_alpha=0.6, fill_color='#fc8d59',
         line_alpha=0.8, line_color='#91bfdb',line_dash='dotted',line_width=5)
p.circle(x=1,y=1,size=100, fill_alpha=0.4, fill_color='#fc8d59',
         line_alpha=1, line_color='#91bfdb',line_dash='solid',line_width=6)
p.x_range = p.y_range = Range1d(-0.5,1.5)
show(p)
```
