#include "fourier_transform.hpp"

#include <cstdlib>
#include <random>
#include <iostream>
#include <string>
#include <algorithm>
#include <numeric>

#include <time.h>
#include <sys/time.h>
#include <sys/resource.h>

#include "tbb/tick_count.h"
#include "tbb/task_scheduler_init.h"

using namespace hpce;

///////////////////////////////////////////////////////////////////////////////
// Very simple testing infrastructure

static std::mt19937 s_urng;

static double randomUniformReal()
{
	std::uniform_real_distribution<double> dst(-1.0, 1.0);
	return dst(s_urng);
}

static complex_t randomUniformComplex()
{
	double re=randomUniformReal();
	double im=randomUniformReal();
	return complex_t(re, im);
}

double totalUserTime()
{
#ifdef __MINGW32__
	HANDLE hProcess = GetCurrentProcess ();
	FILETIME ftCreation, ftExit, ftUser, ftKernel;
	GetProcessTimes (hProcess, &ftCreation, &ftExit, &ftKernel, &ftUser);
	return (uint64_t(ftUser.dwHighDateTime)+ftUser.dwLowDateTime)*1e-7;
#else
	struct rusage usage;
	getrusage(RUSAGE_SELF, &usage);
	struct timeval tv=usage.ru_utime;
	return tv.tv_sec+1e-6*tv.tv_usec;
#endif
}


int main(int argc, char *argv[])
{
	try{
		// Put the system in a known state
		s_urng=std::mt19937(1);

		fourier_transform::RegisterDefaultFactories();

		/////////////////////////////////////////////////////////////////
		// Handle command line arguments

		if(argc<2){
			std::cerr<<"time_fourier_transform name [P] [maxTime]"<<"\n";
			std::cerr<<"    Test the performance of the named fourier transform with P processors."<<"\n";
			std::cerr<<"    P : Number of processors to allow TBB to use.\n";
			std::cerr<<"   log2n : Logarithm of transform size.";
			std::cerr<<"\n    Implementations:\n";

			auto names = fourier_transform::GetTransformFactoryNames();
			auto it=names.begin();
			while(it!=names.end()){
				std::cerr<<"        "<<*it<<std::endl;
				++it;
			}
			return 1;
		}

		std::string name(argv[1]);
		std::shared_ptr<fourier_transform> transform;
		try{
			transform=fourier_transform::CreateTransform(name);
		}catch(...){
			fprintf(stderr, "Exception while trying to create '%s'\n", name.c_str());
			throw;
		}

		unsigned allowedP=0;
		if(argc>2){
			allowedP=atoi(argv[2]);
		}

		double log2n=16.0;
		if(argc>3){
			log2n=strtod(argv[3], NULL);
		}



		//////////////////////////////////////////////////////////
		// Now do timing for increasing sizes

		// This is the default parallelism detected in the machine by TBB
		unsigned trueP=tbb::task_scheduler_init::default_num_threads();

		if(allowedP==0)
			allowedP=trueP;

		// This is the number of parallel tasks that TBB will support
		tbb::task_scheduler_init task_init(allowedP);

//std::cout<<"# name, allowedP, trueP, n, [sentinel], time\n";

		//while(log2n <= 26){	// Try not to blow up memory system
			size_t n=(size_t)std::pow(2.0, log2n);

			// Go for very simpl init
			complex_vec_t input(n, 1.0);
			input[s_urng()%n]=randomUniformComplex();

			tbb::tick_count t_start = tbb::tick_count::now();

			// A single forwards and backwards transform
			input = transform->backwards(transform->forwards(input), n);

			tbb::tick_count t_finish = tbb::tick_count::now();

			double time=(t_finish-t_start).seconds();

			complex_t sentinel=input[s_urng()%n];
			volatile double p;
			p=real(sentinel);

			//std::cout<<transform->name()<<", "<<allowedP<<", "<<trueP<<", "<<n<<", "<<std::abs(sentinel)<<", "<<time<<"\n";


			fprintf(stderr, "user = %lg, time=%lg\n", totalUserTime(), time);

			fprintf(stdout, "parallelism = %.10lf, time = %.10lf\n", totalUserTime()/time, time);
		return 0;
	}catch(std::exception &e){
		std::cerr<<"Caught exception: "<<e.what()<<"\n";
		return 1;
	}catch(...){
		std::cerr<<"Caught unexpected exception type.\n";
		return 1;
	}
}
