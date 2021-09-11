---

title: "Java中的lambda表达式"
tags: ["JAVA"]
date: 2019-11-01
categories: ["Language"]
---

## lambda表达式

Lambda 表达式，也可称为闭包，它是推动 Java 8 发布的最重要新特性。Lambda 允许把函数作为一个方法的参数（函数作为参数传递进方法中）。使用 Lambda 表达式可以使代码变的更加简洁紧凑。

## 语法



lambda 表达式的语法格式如下：

```java
(parameters) -> expression 或 (parameters) ->{ statements; }
```

以下是lambda表达式的重要特征:

- **可选类型声明：**不需要声明参数类型，编译器可以统一识别参数值。
- **可选的参数圆括号：**一个参数无需定义圆括号，但多个参数需要定义圆括号。
- **可选的大括号：**如果主体包含了一个语句，就不需要使用大括号。
- **可选的返回关键字：**如果主体只有一个表达式返回值则编译器会自动返回值，大括号需要指定明表达式返回了一个数值。

## Lambda 表达式的结构

让我们了解一下 Lambda 表达式的结构。

- 一个 Lambda 表达式可以有零个或多个参数
- 参数的类型既可以明确声明，也可以根据上下文来推断。例如：`(int a)`与`(a)`效果相同
- 所有参数需包含在圆括号内，参数之间用逗号相隔。例如：`(a, b)` 或 `(int a, int b)` 或 `(String a, int b, float c)`
- 空圆括号代表参数集为空。例如：`() -> 42`
- 当只有一个参数，且其类型可推导时，圆括号（）可省略。例如：`a -> return a*a`
- Lambda 表达式的主体可包含零条或多条语句
- 如果 Lambda 表达式的主体只有一条语句，花括号{}可省略。匿名函数的返回类型与该主体表达式一致
- 如果 Lambda 表达式的主体包含一条以上语句，则表达式必须包含在花括号{}中（形成代码块）。匿名函数的返回类型与代码块的返回类型一致，若没有返回则为空

### lambda实例

Lambda 表达式的简单例子:

```java
// 1. 不需要参数,返回值为 5  
() -> 5  
  
// 2. 接收一个参数(数字类型),返回其2倍的值  
x -> 2 * x  
  
// 3. 接受2个参数(数字),并返回他们的差值  
(x, y) -> x – y  
  
// 4. 接收2个int型整数,返回他们的和  
(int x, int y) -> x + y  
  
// 5. 接受一个 string 对象,并在控制台打印,不返回任何值(看起来像是返回void)  
(String s) -> System.out.print(s)
```

## lambda表达式的实现原理

在 Java 中，Lambda 表达式是对象，他们必须依附于一类特别的对象类型——[函数式接口(functional interface)](https://www.runoob.com/java/java8-functional-interfaces.html)。函数式接口是只包含一个抽象方法声明的接口。当你试图传入lambda表达式的时候，实际上它是将你传入的表达式隐式的转换并赋值给一个函数式接口，再通过其调用函数。

如：

```java
 @FunctionalInterface
interface Inner {
    void print(int num);
}

public static void wapper(int num, Inner func) {
        func.print(num);
    }
```

```java
wapper(10, e -> {
            for (int i = 0; i < e; i++) {
                System.out.print("HelloWorld\t");
            }
        });

和下面的写法等价
    
 Inner innerFunc = (int e) -> {
            for (int i = 0; i < e; i++) {
                System.out.print("HelloWorld\t");
            }
        };
        wapper(10, innerFunc);


```

