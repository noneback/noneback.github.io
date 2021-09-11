---

title: "C++中左值和右值的区别"
tags: ["C++"]
date: 2019-11-01
categories: ["Language"]
---

# C++中左值和右值的区别

> 最近在复习C++的语法，有一些忘记了的东西，想在这里记录一下

## 什么是左值和右值

### 抽象解释

> In C++ an **lvalue** is something that points to a **specific memory location**. On the other hand, a **rvalue** is something that **doesn't point anywhere**. In general, **rvalues are temporary and short lived**, while **lvalues** live a longer life since they exist as variables.
>
> 参考：[Understanding the meaning of lvalues and rvalues in C++](https://www.internalpointers.com/post/understanding-meaning-lvalues-and-rvalues-c)

### 具体

- **左值**实际上就是有变量名的变量，变量名实际上指向了这个变量分配的内存地址，这个变量名在作用域内可以长期保存
- **右值**实际上是没有变量名的临时变量，变量的内存地址没有实际的变量名去保存，所以说它是临时的，生命周期短的
- **左值**可以转换成**右值**，反之，则不行

```cpp
int a=10;
std::string str="Hello";
//此处的a和str是左值，它们有实际的变量名，并保存其内存的地址，而 10 和 "Hello"则是右值，他们只是临时变量。
int &b=&a;
int *a_p=&a;
//左值往往可以进行取地址操作，而右值则不行
int *a_ptr=&10;//error

//左值转右值
int x = 10;
int y = 10;
int z = x+y;
//这里 x,y本来是左值的，但放在右边相加之后的结果是一个临时的变量，成为了一个右值
```

### 左值右值作为函数的返回值

```cpp
//左值作为函数返回值
int tem=0;

int& getlZero(){
    return tem;
}
getlZero() = 10 //works

//右值最为返回值
int getrZero(){
    return 0;
}

getrZero() = 10//fails

```

## 左值引用和右值引用

### 定义

**左值引用**就是对一个左值进行引用的类型。**右值引用**就是对一个右值进行引用的类型

> 右值引用和左值引用都是属于引用类型。无论是声明一个左值引用还是右值引用，都必须立即进行初始化。
>
> 而其原因可以理解为是引用类型本身自己并不拥有所绑定对象的内存，只是该对象的一个别名。左值引用是具名变量值的别名，而右值引用则是不具名（匿名）变量的别名。
>
> 对引用变量的修改会作用到原变量上。

- 通常左值引用通常也不能绑定到右值，但右值可以借用const+左值引用变量来引用

```cpp
//左右值引用的语法
int a=10;
int &b=a;	//b是a的引用，左值引用
b=20;	//此时a=b=20

int &&c=10;		//c是右值‘10’的引用
c=20 	//此时c变成了‘20’的引用
    
b=10；//error。 10是一个右值，所以报错
c=a;	//error。a是一个左值

const int& a=10;	//works
//	在后台，编译器会创建一个隐藏变量（即左值），以在其中存储原始文字常量，然后将该隐藏变量绑定到引用中
```

### 引用作为函数的参数

```cpp
int getSelfL(int& a){
    return a;
}

int getSelfR(int&& b){
  return b;  
}

int getSelfLR(const int& a){
    return a;
}

int a=10;
getSelfL(a);	//works
getSelfL(10);	//fails

getSelfR(10);	//works
getSelfR(a);	//fails

getSelfRL(10);	//works
```

## 将亡值

> 在C++11之前的右值和C++11中的纯右值是等价的。C++11中的将亡值是随着右值引用的引入而新引入的。
>
> 换言之，“将亡值”概念的产生，是由右值引用的产生而引起的，将亡值与右值引用息息相关。所谓的将亡值表达式，就是下列表达式：
> 			 1）返回右值引用的函数的调用表达式
>
>    2）转换为右值引用的转换函数的调用表达式

 在C++11中，我们用左值去初始化一个对象或为一个已有对象赋值时，会调用拷贝构造函数或拷贝赋值运算符来拷贝资源（所谓资源，就是指new出来的东西）。

而当我们用一个右值（包括纯右值和将亡值）来初始化或赋值时，会调用移动构造函数或移动赋值运算符来移动资源，从而避免拷贝，提高效率。

当该右值完成初始化或赋值的任务时，它的资源已经移动给了被初始化者或被赋值者，同时该右值也将会马上被销毁（析构）。也就是说，当一个右值准备完成初始化或赋值任务时，它已经“将亡”了。而上面1和2两种表达式的结果都是不具名的右值引用，它们属于右值







