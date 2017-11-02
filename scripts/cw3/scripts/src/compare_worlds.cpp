#include "heat.hpp"

#include <cstdlib>
#include <fstream>
#include <stdexcept>
#include <cmath>

int main(int argc, char *argv[])
{	
	float eps=1e-5;
	
	try{
		hpce::world_t A=hpce::LoadWorld(std::cin);
		std::cerr<<"Loaded world under test from stdin with w="<<A.w<<", h="<<A.h<<std::endl;
		
		std::ifstream src(argv[1]);
		if(!src.is_open())
			throw std::invalid_argument(std::string("Couldn't open file '")+argv[1]+"'");
		hpce::world_t B=hpce::LoadWorld(src);
		std::cerr<<"Loaded expected world from file '"<<argv[1]<<"' with w="<<B.w<<", h="<<B.h<<std::endl;
		
		bool fail=false;
		
		if(A.h!=B.h){
			std::cerr<<"MISMATCH: Worlds have different heights.\n";
			fail=true;
		}
		if(A.w!=B.w){
			std::cerr<<"MISMATCH: Worlds have different widths.\n";
			fail=true;
		}
		/*if(std::abs(A.t-B.t) > eps){
			std::cerr<<"MISMATCH: Worlds have different times : stdin = "<<A.t<<" vs expected = "<<B.t<<".\n";
			fail=true;
		}*/
		if(!fail){
			
			int p1=0;
			for(unsigned i=0;i<A.w*A.h;i++){
				if(A.properties.at(i)!=B.properties.at(i)){
					std::cerr<<"MISMATCH: Worlds have different properties (!) at x="<<(i%A.w)<<", y="<<(i/A.w)<<"\n";
					fail=true;
					++p1;
					if(p1 > 10){
						std::cerr<<"  Eliding remaining property mismatches.\n";
						break;
					}
				}
			}
		
			int p2=0;
			
			for(unsigned i=0;i<A.w*A.h;i++){
				float fa=A.state.at(i), fb=B.state.at(i);
				if( std::fabs(fa-fb) > eps){
					std::cerr<<"MISMATCH: Worlds have different state at x="<<(i%A.w)<<", y="<<(i/A.w)<<" : ";
					std::cerr<<"got "<<fa<<", expected "<<fb<<"\n";
					fail=true;
					++p2;
					if(p2 > 10){
						std::cerr<<"  Eliding remaining property mismatches.\n";
						break;
					}
				}
			}
		}
		
		if(!fail){
			std::cerr<<"Success: No errors found.\n";
		}
		
		return fail?1:0;
	}catch(const std::exception &e){
		std::cerr<<"Exception : "<<e.what()<<std::endl;
		return 1;
	}
		
	return 0;
}
