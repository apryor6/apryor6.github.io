
# Bokeh Ray Glyph


```python
from bokeh.plotting import figure, output_file, show
from bokeh.models import Range1d, ColumnDataSource
from bokeh.io import export_png
from math import pi
import numpy as np
import matplotlib.cm as cm
import pandas as pd

output_file("../../figures/ray.html")
num_lines = 51
source = pd.DataFrame(dict(
x = [0.5]*num_lines,
y = [0.5]*num_lines,
length = np.linspace(0.1,0.9,num_lines),
angle = np.linspace(0,4*pi,num_lines, endpoint=False)
))

cmap = cm.get_cmap('viridis')
source['colors'] = ["#%02x%02x%02x" % (int(r), int(g), int(b)) for r, g, b, a in 255*cmap(source['length'])]
source = ColumnDataSource(source) 

p = figure(plot_width=400, plot_height=400)
p.ray(x='x', y='y', length='length', angle='angle', source=source, line_cap='round',
         line_alpha=1, line_color='colors', line_dash='solid', line_width=5)
p.x_range = Range1d(-0.25, 1.25, bounds=(-1,2))
p.y_range = Range1d(-0.25, 1.25, bounds=(-1,2))
show(p)
export_png(p, filename="../../figures/ray.png");
```
