---

title: "元素布局与定位"
tags: ["CSS"]
date: 2018-11-01
categories: ["Language"]
---

## 元素布局与定位  
### position 位置属性
>   其中有relative，absolute，static，fixed  

1.relative：相对布局，相对于原来的文档流中的位置（默认位置），有left，right，top，bottom。  

2.static：即默认文档流的位置  

3.absolute：绝对位置，脱离出常规文档流，其原有的元素位置被回收，被其他元素顶替。其本身则相对于顶级元素body元素定位布局
> 关于定位的重要概念：**定位上下文**  


4.fixed:固定定位，完全移除文档流，与absolute绝对定位类似。但它是相对于视口（浏览器窗口或者屏幕），因此**它不会随着窗口的滚动而移动**。  
#### 定位上下文  
> 相对定位的参考元素，只有其存在才可进行相关的定位  

### display 显示属性   
属性值有block、inline，和none。它可以更改元素的显示模式，如将块级元素以行内元素显示。  
其中对于设定为none属性值的元素，它们都不会在页面中显示出来，原本所占有的空间也会被回收
> ps:回顾 
> - 块级元素，比如段落、标题、列表等，在浏览器中上下堆叠显示。   
> - 行内元素，比如a、span、img，在浏览器中左右并排显示，只有前一行没有空间的时候才会显示到下一行。 
### 背景  
背景属性：
1.颜色： 

    background-color    
2.图片及与其相关的属性：  

    background-image：url图片路径/图片文件名）添加背景图片
    background-repeat：选择图片的重复方式，有 no—repeat，repeat-x，-y等

3.背景的位置：  

    background-position：用于控制背景的位置布局，控制的方法有关键字、百分比、与像素（ps：注意其基准点的不同）

4.背景的尺寸：

    background-size：用来控制背景图片的尺寸。
    控制方法：
    1.百分比：按比例缩放  
    2.像素：固定缩放  
    3.cover：拉大图片，使其完全填满背景区，保持宽高比
    4.contain：缩放图片，使其恰好适合背景区，保持宽高比

5.背景粘附：

    background-attachment：控制滚动元素内背景图片是否随滚动元素而滚动。
    如：background-attachment：fixed；
6.简写背景属性：
> 即将‘-’后面的内容省略，直接将属性只写在括号内。 
如：

    body{background:url(.../...) fixed no-repeat}

**ps**:CSS允许添加多背景图片，其中先添加的图片位于上层。

## 字体
字体样式的属性：

1.font-family:字体族，字体类型，可继承。  

> 设置字体栈:以防字体无效，多罗列出一些字体以备用，如：  

    body{font-family:"trebuchet ms"(当字体名字有空格时，用”“括起来),tahoma,sans-sreif;}
    //按先后顺序优先

2.font-size:字体大小，有相对单位与绝对单位，相对单位可继承。  

> - 绝对单位：像素与一些如同x-small等基准大小
> - 相对单位：百分比、em、rem。
> - 如果给某个元素设定了相对字体大小，则该元素的字体大小要相对于**最近的设定过字体大小的祖先元素**来确定。 
> - rem相对单位：相对与HTML根元素的大小。集两种单位的优点于一身。

3.font-style:字体样式，设定是正体还是 斜体  
> 属性值：italic（斜体）、oblique（斜体）、normal（正体）。  

4.font-wight:字体粗细
> 属性值：100......等以及bold和normal等  

5.font-variant:字体变化
> 属性值：normal，small-caps
6.font(简写属性):  

示例：

    p{font:bold italic small-caps .9em helvetica,arial,san-serif;} 

### 文本属性

    p{
        text-indent:3em;  
        letter-spacing：2em；  
        word-spacing：2em；  
        text-decoration：underline；  
        text-align:center;  
        text-height：1.5（即为字体的1.5倍）；  
        span：vertical-align：60%；  
    
        }

 1.text-indent:文本缩进,正值向右缩进。属性可被子元素继承，且继承的是依据父元素计算的具体数值。  
     
 2.letter-spacing:在默认基础上改变字符间距,无论如何一定要使用相对单位，以便缩放。  

 3.word-spacing：单词间距，类似。  

 4.text-decoration:文本装饰，主要用于链接添加下划线。
 > 属性值：underline、overline、line-through、blink、none  

 5.text-align:文本对齐
 > 属性值：left，right，center、justify（两端对齐）。  

 6.line-height：行高，与外边距不同，不叠加，其余类似。属性值为任意的值，不用添加单位。可用于除去大标题的空白。  
 7.text-transformation：用于转换字母的大小写。  
 8.span：垂直对齐，属性值为任意数值或者一些关键字。用于书写上标或者下标。  
 ## web字体大揭秘 
 可调用远程服务器中的字体给浏览器使用。



​     





  









