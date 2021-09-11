---
title: "HTTPS浅析"
date: 2021-02-21T16:48:55+08:00
lastmod: 2021-02-21T16:48:55+08:00
mathjax: true
keywords: ["HTTPS","HTTP"]
tags: ["Network","HTTPS","HTTP"]
categories: ["Computer Network"]
draft: false
author: "NoneBack"
comment: false
toc: true
autoCollapseToc: true
reward: false

flowchartDiagrams:
  enable: true
  options: ""

sequenceDiagrams: 
  enable: true
  options: ""
---
​	HTTPS(HTTP over SSL)是为了解决HTTP中可能存在的信息窃听和身份伪装等安全问题而诞生的HTTP加密版本，通常使用 [SSL](https://developer.mozilla.org/en-US/docs/Glossary/SSL) 或者 [TLS](https://developer.mozilla.org/en-US/docs/Glossary/TLS) 来加密客户端和服务器之间所有的通信 

## HTTP的问题

- 通信使用明文，内容可能会被窃听
- 无法验证通信方的身份，因此可能遭遇伪装(如Dos,Denial of Service attack)
- 无法证明报文的完整性，报文可能在通信中被篡改(如MITM,Man-in-the-Middle attack)

为了解决以上等问题，我们需要

- 加密处理，防止被窃听

  > 可以对**内容**加密，或者对**通信**加密以简历安全通信线路

- 需要验证通信方的身份，防止伪装攻击

  > 如利用证书验证身份

- 要能确定报文的完整性，防止被篡改

  > 常用的有MD5和SHA-1散列值校验的方法等

## HTTPS

​	为了统一解决上诉的问题，需要在HTTP上再加上加密处理、认证、完整性保护等机制，我们称之为HTTP Secure or HTTP over SSL

​						$HTTP + 加密 + 认证 + 完整性保护 = HTTPS$

### HTTPS over SSL

​	HTTPS并非是应用层的新协议，它只是HTTP通信接口部分使用SSL和TSL协议代替。它在HTTP与TCP协议中添加了一个SSL协议，使HTTP拥有HTTPS的加密、证书、完整性保护等功能。

![image.png](https://i.loli.net/2021/02/21/cdQk9AGJUCF4MLI.png)

> ​	SSL独立于HTTP的协议，应用层SMTP和Telnet等协议均可与之搭配使用，并获得加密等功能。

### 加密机制

​	HTTPS采用共享密钥和公开密钥加密两者并用的混合加密机制，充分利用两者各自的优势

- 利用公开密钥加密机制加密共享密钥(Pre-master secret)，避免共享密钥被窃取
- 通信时，则利用共享密钥加密机制，保证性能

> 两者主要差别：
>
> ​	公开密钥：非对称加密，安全，但处理复杂，效率低
>
> ​	共享密钥：对称加密机制，相对不安全，传输密钥时可能被窃取，但效率更高

### 认证机制

​	使用共享密钥加密时，需要证明公开密钥本身就是货真价实，未被替换，所以我们在传输公钥之前对通信方认证。

​	HTTPS通过使用**证书**来对通信方进行验证。

​	使用由数字证书认证机构(CA，Certificate Authority)和其颁发的公开密钥证书，认证公开密钥。

> 数字证书认证机构（CA，Certificate Authority）是客户端与服务器双方都可信赖的第三方机构。服务器的运营人员向 CA 提出公开密钥的申请，CA 在判明提出申请者的身份之后，会对已申请的公开密钥做数字签名，然后分配这个已签名的公开密钥，并将该公开密钥放入公开密钥证书后绑定在一起。

- 服务器首先将公钥证书利用公开密钥加密的方式发送给客户端
- 客户端收到后，利用数字认证机构的公开密钥，对此证书的数字千米进行验证，如通过，则可证明：
  - 数字证书认证机构后真实有效
  - 服务端的公开密钥可信
- 通信双方利用这对公钥私钥进行加密和解密，得到共享的密钥

> 数字认证机构的公开密钥一般事先在浏览器内部植入

### 完整性保护机制

HTTPS主要使用摘要算法来保护报文的完整性

#### 摘要算法

又称哈希算法、散列算法。它通过一个函数，把任意长度的数据转换为一个长度固定的数据串，常见的有MD5，SHA-2等

> 摘要算法**不是加密算法**，不能用于加密（因为无法通过摘要反推明文），**只能用于防篡改**，但是它的单向计算特性决定了可以在不存储明文口令的情况下验证用户口令。

应用层发送数据时会附加Message Authentication Code报文摘要。MAC能查知报文是否遭到了篡改，从而保护报文的完整性。

## HTTPS 通信流程

![image-20210221163750864](https://i.loli.net/2021/02/21/BWwJxbpPETst5ug.png)![image-20210221163944755](https://i.loli.net/2021/02/21/XOVojxhzP7qw1SH.png)

## 其他

- 由于需要加密解密处理以及SSL握手等过程，需要更多的网络负载，以及CPU资源性能上HTTPS比HTTP慢很多

  > 一般利用SSL加速器(专用服务器)来改善问题

- 浏览器客户端访问同一个https服务器，可以不必每次都进行完整的TLS Handshake。

  > ​	服务器会为每个浏览器（或客户端软件）维护一个session ID，在TSL握手阶段传给浏览器，浏览器生成好密钥(Pre-Master secret)传给服务器后，服务器会把该密钥存到相应的session ID下，之后浏览器每次请求都会携带session ID，服务器会根据session ID找到相应的密钥并进行解密加密操作。
  >
  > ​	如果没有此ID，则需要完整的进行TLS Handshake

## 参考

- [MDN](https://developer.mozilla.org/zh-CN/docs/Glossary/https)
- [wikipeida](https://zh.wikipedia.org/wiki/%E8%B6%85%E6%96%87%E6%9C%AC%E4%BC%A0%E8%BE%93%E5%AE%89%E5%85%A8%E5%8D%8F%E8%AE%AE#%E4%B8%8EHTTP%E7%9A%84%E5%B7%AE%E5%BC%82)
- [cxuan’s blog](https://www.cnblogs.com/cxuanBlog/p/12490862.html)
- 《图解HTTP/HTTPS》
