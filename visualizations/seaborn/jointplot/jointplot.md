
# seaborn.jointplot
---
Seaborn's `jointplot` displays a relationship between 2 variables (bivariate) as well as 1D profiles (univariate) in the margins. This plot is a convenience class that wraps [JointGrid](http://seaborn.pydata.org/generated/seaborn.JointGrid.html#seaborn.JointGrid).



```python
%matplotlib inline
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
plt.rcParams['figure.figsize'] = (20.0, 10.0)
plt.rcParams['font.family'] = "serif"
```

The multivariate normal distribution is a nice tool to demonstrate this type of plot as it is sampling from a multidimensional Gaussian and there is natural clustering. I'll set the covariance matrix equal to the identity so that the X and Y variables are uncorrelated -- meaning we will just get a blob


```python
# Generate some random multivariate data
x, y = np.random.RandomState(8).multivariate_normal([0, 0], [(1, 0), (0, 1)], 1000).T
df = pd.DataFrame({"x":x,"y":y})

```

Default plot


```python
p = sns.jointplot(data=df,x='x', y='y')
```


![png](output_5_0.png)


Currently, `jointplot` wraps `JointGrid` with the following options for `kind`:  
    - scatter
    - reg
    - resid 
    - kde 
    - hex 

Scatter is the default parameters


```python
p = sns.jointplot(data=df,x='x', y='y',kind='scatter')
```


![png](output_8_0.png)


'reg' plots a linear regression line. Here the line is close to flat because we chose our variables to be uncorrelated


```python
p = sns.jointplot(data=df,x='x', y='y',kind='reg')
```


![png](output_10_0.png)


'resid' plots the residual of the data to the regression line -- which is not very useful for this specific example because our regression line is almost flat and thus the residual is almost the same as the data.


```python
x2, y2 = np.random.RandomState(9).multivariate_normal([0, 0], [(1, 0), (0, 1)], len(x)).T
df2 = pd.DataFrame({"x":x,"y":y2})

p = sns.jointplot(data=df,x='x', y='y',kind='resid')
```


![png](output_12_0.png)


`kde` plots a kernel density estimate in the margins and converts the interior into a shaded countour plot


```python
p = sns.jointplot(data=df,x='x', y='y',kind='kde')
```


![png](output_14_0.png)


'hex' bins the data into hexagons with histograms in the margins. At this point you probably see the "pre-cooked" nature of `jointplot`. It provides nice defaults, but if you wanted, for example, a KDE on the margin of this hexplot you will need to use `JointGrid`.


```python
p = sns.jointplot(data=df,x='x', y='y',kind='hex')
```


![png](output_16_0.png)


`stat_func` can be used to provide a function for computing a summary statistic from the data. The full x, y data vectors are passed in, so the function must provide one value or a tuple from many. As an example, I'll provide `tmin`, which when used in this way will return the smallest value of x that was greater than its corresponding value of y.


```python
from scipy.stats import tmin
p = sns.jointplot(data=df, x='x', y='y',kind='kde',stat_func=tmin)

# tmin is computing roughly the equivalent of the following
print(df.loc[df.x>df.y,'x'].min())
```

    -1.37265900987



![png](output_18_1.png)


Change the color


```python
p = sns.jointplot(data=df,
                  x='x',
                  y='y',
                  kind='kde',
                  color="#99ffff")
```


![png](output_20_0.png)

`ratio` adjusts the relative size of the marginal plots and 2D distribution

```python
p = sns.jointplot(data=df,
                  x='x',
                  y='y',
                  kind='kde',
                  ratio=1)
```


![png](output_22_0.png)


Create separation between 2D plot and marginal plots with `space`


```python
p = sns.jointplot(data=df,
                  x='x',
                  y='y',
                  kind='kde',
                  space=2)
```


![png](output_24_0.png)


`xlim` and `ylim` can be used to adjust the field of view


```python
p = sns.jointplot(data=df,
                  x='x',
                  y='y',
                  kind='kde',
                  xlim=(-15,15),
                  ylim=(-15,15))
```


![png](output_26_0.png)


Pass additional parameters to the marginal plots with `marginal_kws`. You can pass similar options to `joint_kws` and `annot_kws`


```python
p = sns.jointplot(data=df,
                  x='x',
                  y='y',
                  kind='kde',
                  marginal_kws={'lw':5,
                                'color':'red'})

```


![png](output_28_0.png)


Finalize


```python
sns.set(rc={'axes.labelsize':30,
            'figure.figsize':(20.0, 10.0),
            'xtick.labelsize':25,
            'ytick.labelsize':20})

from itertools import chain
p = sns.jointplot(data=df,
                  x='x',
                  y='y',
                  kind='kde',
                  xlim=(-3,3),
                  ylim=(-3,3),
                  marginal_kws={'lw':3}).set_axis_labels('X','Y')
p.ax_marg_x.set_facecolor('#ccffccaa')
p.ax_marg_y.set_facecolor('#ccffccaa')
for l in chain(p.ax_marg_x.axes.lines,p.ax_marg_y.axes.lines):
    l.set_linestyle('--')
    l.set_color('black')
plt.text(-2.1,-2.5, "Joint Plot", fontsize = 55, color='Black', fontstyle='italic')
```




    <matplotlib.text.Text at 0x10cfd0eb8>




![png](output_30_1.png)



```python
p.savefig('../../figures/jointplot.png')
```


```python

```
