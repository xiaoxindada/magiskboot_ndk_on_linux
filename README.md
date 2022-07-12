## Magiskboot_ndk
> 这是一个从[magisk](https://github.com/topjohnwu/Magisk) native 中分离出来的供单独编译的源码  
> 使用 [cygwin](https://www.cygwin.com/) 环境编译 给Windows使用  

## 克隆源码:
> git clone --recurse-submodules https://github.com/xiaoxindada/magiskboot_ndk_on_linux.git  -b cygwin magiskboot_on_cygwin  
> cd magiskboot_on_cygwin  
> git pull --recurse-submodules  

## 安装编译依赖:  
> make gcc-g++ github iconv-devel zlib-devel clang

## 编译:
> ./build.sh  

## 生成物路径:
> out  

## 学分
[affggh](https://github.com/affggh)  
