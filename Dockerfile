FROM ubuntu:17.04	

MAINTAINER Andreas Paffenholz <paffenholz@mathematik.tu-darmstadt.de>

LABEL version = "1.0"
LABEL description = "polymake container"

### initial update of ubuntu, 
### sudo seems to be missing in base install
### Install necessary ubuntu packages
RUN apt-get update -qq && apt-get -qq install -y apt-transport-https  \
	&& apt-get -qq install -y \
    4ti2 \
	ant ant-optional autoconf autogen \
    bliss build-essential bzip2 \
	clang \
	debhelper default-jdk \
    git graphviz \
    language-pack-en language-pack-el-base libbliss-dev libboost-dev \
	libboost-python1.62-dev libboost-python-dev libcdd0d libcdd-dev libdatetime-perl libflint-2.5.2 \
	libflint-dev libglpk-dev libgmp-dev libgmp10 libgmpxx4ldbl libmpfr-dev libncurses5-dev libmongodb-perl libnormaliz0 libntl27 libntl-dev \
	libperl-dev libppl-dev libreadline6-dev libterm-readline-gnu-perl libterm-readkey-perl \
	libsvn-perl libtool libxml-libxml-perl libxml-libxslt-perl libxml-perl libxml-writer-perl libxml2-dev libxslt-dev \
    m4 make mongodb \
	nano \
	python-dev \
	sudo \
	wget \
    xsltproc
		
### create a user polymake
### give it sudo access, nopassword
RUN adduser --quiet --shell /bin/bash --gecos "polymake user,101,," --disabled-password polymake \
    && adduser polymake sudo \
    && chown -R polymake:polymake /home/polymake/ \
    && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
	&& mkdir /home/polymake/src \
    && sudo chown -hR polymake /home/polymake/src

USER polymake
ENV HOME /home/polymake
WORKDIR /home/polymake


# the jreality sources contain umlauts, so we have to ensure that those can be processed properly...
RUN sudo locale-gen en_US.UTF-8  
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US:en  
ENV LC_ALL en_US.UTF-8  

### singular with sources from github
### we use a version before 2016-12-01, later versions don't compile properly?
RUN cd /home/polymake/src \
    && mkdir Singular4 \
    && cd Singular4 \
    && git clone https://github.com/Singular/Sources.git \
    && cd Sources \
    && git checkout `git rev-list -n 1 --before="2016-12-01 00:00" spielwiese` \
    && ./autogen.sh \
    && ./configure --enable-gfanlib --with-flint=/usr/local --disable-polymake --prefix=/home/polymake/singular \
    && make && make check && make install \
	&& cd /home/polymake/src \
	&& rm -rf Singular4*

### topcom
### this adds around 300MB, mostly because it comes with its own versions of everything,
### reusing existing ones somehow does not work properly...
RUN cd /home/polymake/src \ 
    && wget http://www.rambau.wm.uni-bayreuth.de/Software/TOPCOM-0.17.8.tar.gz \
	&& tar -xf TOPCOM-0.17.8.tar.gz \
	&& cd topcom-0.17.8 \
    && ./configure \
    && make && sudo make install \
    && cd .. \
    && rm -rf TOPCOM*	

	
### Polymake
### enabled java to save jreality images to file
### no sketch as pgf/texlive is huge
RUN cd /home/polymake/src \
    && git clone --branch Snapshots --depth 1 https://github.com/polymake/polymake.git polymake \
    && cd polymake \
    && ./configure --with-singular=/home/polymake/singular \
    && make \
    && sudo make install \
    && cd .. \
    && rm -rf polymake*


### remove build dir
RUN rm -rf /home/polymake/src


### some polymake extensions
### we keep them locally
RUN mkdir /home/polymake/extensions \
    && sudo chown -hR polymake /home/polymake/extensions \
    && cd /home/polymake/extensions  \
	&& git clone --depth 1 https://github.com/apaffenholz/polymake_flint_wrapper.git \
	&& git clone --depth 1 https://github.com/apaffenholz/lattice_normalization.git \
	&& cd /home/polymake/extensions \
    && echo 'use application "common"; import_extension("/home/polymake/extensions/polymake_flint_wrapper"); import_extension("/home/polymake/extensions/lattice_normalization");' > import_ext.pl \
	&& cd /home/polymake/extensions \	
	&& script -c 'TERM=xterm polymake --iscript /home/polymake/extensions/import_ext.pl /dev/null' \
	&& rm import_ext.pl
	
	
RUN polymake 'my $c=cube(3);'
	
ENTRYPOINT [ "polymake" ]