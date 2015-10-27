FROM ubuntu:15.10

MAINTAINER Andreas Paffenholz <paffenholz@mathematik.tu-darmstadt.de>

LABEL version = "1.0"
LABEL description = "polymake container"

### initial update of ubuntu, 
### sudo seems to be missing in base install
### Install necessary ubuntu packages
RUN apt-get update -qq \
	&& apt-get -qq install -y \
    ant ant-optional autoconf \
    bliss build-essential bzip2 \
	clang \
	debhelper default-jdk \
    git graphviz \
    language-pack-en libbliss-dev libboost-dev libcdd-dev libdatetime-perl libglpk-dev libgmp-dev libgmp3-dev libgmpxx4ldbl libmpfr-dev libncurses5-dev libmongodb-perl libntl-dev \
	libperl-dev libppl-dev libreadline6-dev libterm-readline-gnu-perl libterm-readkey-perl libsvn-perl libtool libxml-libxml-perl libxml-libxslt-perl libxml-perl libxml-writer-perl libxml2-dev \
    m4 make mongodb \
	nano \
	sudo \
    w3c-dtd-xhtml wget \
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


### flint2 library 
RUN cd /home/polymake/src \
    && git clone https://github.com/wbhart/flint2.git \
    && cd flint2 \
    && ./configure  \
    && make && sudo make install \
    && cd .. \
    && rm -rf flint2


### 4ti2
RUN cd /home/polymake/src \
    && wget http://www.4ti2.de/version_1.6.6/4ti2-1.6.6.tar.gz \
    && tar -xf 4ti2-1.6.6.tar.gz \
    && cd 4ti2-1.6.6 \
    && ./configure --enable-shared \
    && make && sudo make install \
    && cd .. \
    && rm -rf 4ti2*
		

### singular with sources from github
RUN cd /home/polymake/src \
    && mkdir Singular4 \
    && cd Singular4 \
    && git clone https://github.com/Singular/Sources.git \
    && cd Sources \
    && ./autogen.sh \
    && ./configure --enable-gfanlib --with-flint=/usr/local \
    && make && make check && sudo make install \
	&& cd /home/polymake/src \
	&& rm -rf Singular4*


### latte (the lean install reusing the already installed versions of gmp, cdd does not work, lidia is broken in this release)
### further, latte can't handle installation into system dirs properly (make needs to be run as root and messes around), so we keep it local
### this is a huge waste of space (approx 500MB), so maybe don't install it at all?
RUN cd /usr/local/share \ 
    && sudo wget https://www.math.ucdavis.edu/~latte/software/packages/latte_current/latte-integrale-1.7.3.tar.gz \
	&& sudo tar -xf latte-integrale-1.7.3.tar.gz \
    && sudo chown -hR polymake latte-integrale-1.7.3 \
	&& cd latte-integrale-1.7.3 \
    && ./configure \
    && make && sudo make install
	
### add latte binaries to path
ENV PATH $PATH:/usr/local/share/latte-integrale-1.7.3/dest/bin

### topcom
### this adds around 300MB, mostly because it comes with its own versions of everything,
### reusing existing ones again does not work properly...
RUN cd /home/polymake/src \ 
    && wget http://www.rambau.wm.uni-bayreuth.de/Software/TOPCOM-0.17.5.tar.gz \
	&& tar -xf TOPCOM-0.17.5.tar.gz \
	&& cd TOPCOM-0.17.5 \
    && ./configure \
    && make && sudo make install \
    && cd .. \
    && rm -rf TOPCOM*	


	
	
### Polymake
### enabled java to save jreality images to file
### no sketch as pfg/texlive is huge
RUN cd /home/polymake/src \
    && git clone --branch Snapshots --depth 1 https://github.com/polymake/polymake.git polymake \
    && cd polymake \
    && ./configure \
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
    && cd /home/polymake/extensions \
    && git clone --depth 1 https://github.com/solros/poly_db.git \
	&& git clone --depth 1 https://github.com/apaffenholz/polymake_flint_wrapper.git \
	&& git clone --depth 1 https://github.com/apaffenholz/lattice_normalization.git \
	&& cd /home/polymake/extensions \
    && echo 'use application "common"; import_extension("/home/polymake/extensions/poly_db"); import_extension("/home/polymake/extensions/polymake_flint_wrapper","--with-flint=/usr/local"); import_extension("/home/polymake/extensions/lattice_normalization");' > import_ext.pl
	
RUN	cd /home/polymake/extensions \	
	&& script -c 'TERM=xterm polymake --iscript /home/polymake/extensions/import_ext.pl /dev/null' \
	&& rm import_ext.pl
	
	
RUN polymake 'my $c=cube(3);'
	
ENTRYPOINT [ "polymake" ]