/*
 RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
 Copyright 2023, School of Computer and Communication Sciences, EPFL.

 All rights reserved. Use of this source code is governed by a
 BSD-style license that can be found in the LICENSE.md file. 
*/

/*
This source file is based on the artifact of VITI: A Tiny Self-Calibrating Sensor for Power-Variation Measurement in FPGAs
Which itself was modified from the following repo https://github.com/hasindu2008/PowerAnalysis/tree/master/4.analysis/cuda repository authored by Hasindu Gamaarachchi, Harsha Ganegoda and Roshan Ragel.
Please give due credit to the original authors by also citing their work:
* https://doi.org/10.46586/tches.v2022.i1.657-678 
* https://doi.org/10.1109/ICIINFS.2015.7399063
*/

#include "data.cuh"
#include "utils.cuh"
#include <cuda.h>
#include <stdio.h>
#include <string>
#include <stddef.h>


// GPU index
#define GPUIDXINT 0
#define GPUIDXSTR "0"

// Single run or multi run (comment the definition to switch to single run)
#define MULTIRUN

// length of the key
#define KEYBYTES 16

// there are 2^8 = 256 possibilities for each byte
#define KEYS 256

#ifdef MULTIRUN
#define ROUNDS_PER_STEP 1 // Number of CPA executions with a given number of power traces - For random selection of traces
#define MULTIRUN_SUMMARY
#endif // MULTIRUN

__device__ byte hamming_weight(byte M, byte R);
__device__ byte hamming(unsigned int *cipherText, unsigned int sample, unsigned int n, unsigned int key);
__global__ void max_correlation_kernel(double *correlation, double *waveStat, double *waveStat2, double *hammingStat, unsigned int samplesToProcess, int WAVELENGTH);
__global__ void wave_stat_kernel(double *waveData, double *waveStat, double *waveStat2, byte *hammingArray, byte *hammingArray2, unsigned int samplesToProcess, int WAVELENGTH);
__global__ void hamming_kernel(unsigned int *cipherText, byte *hammingArray,byte *hammingArray2, double *hammingStat, unsigned int samplesToProcess);

#ifdef MULTIRUN_SUMMARY
void cpa_single(int argc, char *trace_path, unsigned int *cipherTextRead, unsigned int samplesToProcess, int total, int ROUNDKEY[KEYBYTES], int WAVELENGTH, int CHUNK, char output_path[1000], unsigned int *keyByteIndex);
#endif // MULTIRUN_SUMMARY
#ifndef MULTIRUN_SUMMARY
void cpa_single(int argc, char *trace_path, unsigned int *cipherTextRead, unsigned int samplesToProcess, int total, int ROUNDKEY[KEYBYTES], int WAVELENGTH, int CHUNK, char output_path[1000]);
#endif // !MULTIRUN_SUMMARY
void randomize_selection(unsigned int *selection, unsigned int samplesToProcess);
void log_correlations_each_iteration(int iteration, double *correlation, unsigned int samplesToProcess, char output_path[1000]);
void log_maxCorrelation(double *maxCorrelation, unsigned int samplesToProcess, unsigned int file_index, char output_path[1000]);
void log_correlation_known_key_csv(double *maxCorrelation, int ROUNDKEY[KEYBYTES], char output_path[1000]);
void sort_correlations(double finalCorrelations[KEYS][KEYBYTES], int positions[KEYS][KEYBYTES], double *maxCorrelation);
void log_highest_correlation_csv(double finalCorrelations[KEYS][KEYBYTES], char output_path[1000]);
void log_top_k_correlations(double finalCorrelations[KEYS][KEYBYTES], int positions[KEYS][KEYBYTES], int k, char output_path[1000]);
void print_top_k_correlations(double finalCorrelations[KEYS][KEYBYTES], int positions[KEYS][KEYBYTES], int k);
void isMemoryFull(unsigned int *ptr);
//functions for multiple CPA attacks
void log_correct_keybyte_count_csv(int positions[KEYS][KEYBYTES], int ROUNDKEY[KEYBYTES], char output_path[1000]);
void log_misc_string(char *str, char output_path[1000]);
void multirun_update_summary(int positions[KEYS][KEYBYTES], unsigned int keyByteIndex[KEYBYTES], int ROUNDKEY[KEYBYTES]);
void log_keybyte_summary(int i, unsigned int keyByteIndex[KEYBYTES], char output_path[1000]);

int main(int argc, char *argv[]) {
	cudaSetDevice(GPUIDXINT);

	FILE *file;
        config_t config;

        // Load program config passed by the command line arguments
        init_config(&config);
        if(parse_args(argc, argv, &config) == EXIT_FAILURE)
	  exit(EXIT_FAILURE);
        if(print_config(&config) == EXIT_FAILURE)
	  exit(EXIT_FAILURE);

        int SAMPLES_WAVE = config.n_traces; 
        int TOTAL = config.n_samples; 
        int STEPSIZE = config.step_size;
        int ROUNDKEY[16];
        memcpy(ROUNDKEY, config.key, sizeof(config.key));
        int WAVELENGTH = TOTAL;
        int UPPERBOUND = SAMPLES_WAVE;
        int LOWERBOUND = STEPSIZE;
        int CHUNK = TOTAL;
        char output_path[1000];
        memcpy(output_path, config.dump_path, sizeof(config.dump_path));

	unsigned int *cipherTextRead = (unsigned int *)malloc(sizeof(unsigned int) * SAMPLES_WAVE * KEYBYTES);

	isMemoryFull(cipherTextRead);

	//get ciphertexts
        printf("Ciph file: %s\n", config.ciphertext_path);
	file = fopen(config.ciphertext_path, "r");
	//isFileOK(file);
	for (int i = 0; i < SAMPLES_WAVE; i++) {
		for (int j = 0; j < KEYBYTES; j++) {
			fscanf(file, "%X", &cipherTextRead[(i / 1)*KEYBYTES + j]);
		}
	}
	printf("ciphertext: %X %X \n", cipherTextRead[SAMPLES_WAVE*KEYBYTES-1], cipherTextRead[1]);
	fclose(file);
	
#ifdef MULTIRUN

#ifdef MULTIRUN_SUMMARY
	unsigned int *keyByteIndex = (unsigned int *)malloc(sizeof(unsigned int) *  KEYBYTES);
#endif // MULTIRUN_SUMMARY
	
	int i = UPPERBOUND;
	while (i >= LOWERBOUND) {
#ifdef MULTIRUN_SUMMARY
		for (int n = 0; n < KEYBYTES; n++) {
			keyByteIndex[n] = 0;
		}
#endif // MULTIRUN_SUMMARY
		char str_i[10];
		sprintf(str_i, "%d", i);
		log_misc_string(str_i, output_path);
		for (int j = 0; j < ROUNDS_PER_STEP; j++) {
			log_misc_string(",", output_path);
#ifdef MULTIRUN_SUMMARY
			cpa_single(argc, config.trace_path, cipherTextRead, i, TOTAL, ROUNDKEY, WAVELENGTH, CHUNK, output_path, keyByteIndex);
#endif // MULTIRUN_SUMMARY
#ifndef MULTIRUN_SUMMARY
			cpa_single(argc, config.trace_path, cipherTextRead, i, TOTAL, ROUNDKEY, WAVELENGTH, CHUNK, output_path);
#endif // !MULTIRUN_SUMMARY
		}	
#ifdef MULTIRUN_SUMMARY
		log_keybyte_summary(i, keyByteIndex, output_path);

#endif //MULTIRUN_SUMMARY
		log_misc_string("\n", output_path);
		i = i - STEPSIZE;
	}
#endif // MULTIRUN

#ifndef MULTIRUN
	cpa_single(argc, config.trace_path, cipherTextRead, SAMPLES_WAVE, TOTAL, ROUNDKEY, WAVELENGTH, CHUNK, output_path);
#endif // !MULTIRUN

#ifdef MULTIRUN_SUMMARY
	free(keyByteIndex);
#endif //MULTIRUN_SUMMARY
	free(cipherTextRead);
	return 0;
}


#ifdef MULTIRUN_SUMMARY
void cpa_single(int argc, char *trace_path, unsigned int *cipherTextRead, unsigned int samplesToProcess, int total, int ROUNDKEY[KEYBYTES], int WAVELENGTH, int CHUNK, char output_path[1000], unsigned int *keyByteIndex) {
#endif // MULTIRUN_SUMMARY
#ifndef MULTIRUN_SUMMARY
void cpa_single(int argc, char *trace_path, unsigned int *cipherTextRead, unsigned int samplesToProcess, int total, int ROUNDKEY[KEYBYTES], int WAVELENGTH, int CHUNK, char output_path[1000]) {
#endif // !MULTIRUN_SUMMARY
	FILE *file;
	float dat;
	unsigned int i, j, k, temp;

	double *maxCorrelation = (double *)malloc(sizeof(double) * KEYS* KEYBYTES);
	isMemoryFull( (unsigned int*) maxCorrelation);
	for (i = 0; i < KEYS; i++) {
		for (j = 0; j < KEYBYTES; j++) {
			maxCorrelation[i*KEYBYTES + j] = 0;
		}
	}

	double *waveDataRead = (double *)malloc(sizeof(double) * samplesToProcess * CHUNK);
	
	isMemoryFull((unsigned int*)  waveDataRead);

	//space for correlation
	double *correlation = (double *)malloc(sizeof(double) * KEYS * KEYBYTES);
	isMemoryFull((unsigned int*)correlation);

	unsigned int *selection = (unsigned int *)malloc(sizeof(unsigned int) * samplesToProcess);

	isMemoryFull((unsigned int*)selection);

	for (i = 0; i < samplesToProcess; i++) {
		selection[i] = i;
	}
	//randomize_selection(selection, samplesToProcess);

	int numOfChunks = total / CHUNK;
	int l = 0;
	for (l = 0; l < numOfChunks; l++) {
		file = fopen(trace_path, "r");
		//isFileOK(file);
		int fileLength = strlen(trace_path);
		char extention[5];
		strncpy(extention, trace_path + fileLength - 4, 4);
		extention[4] = 0;
		if (strcmp(extention, "data") == 0) {
			fprintf(stderr, "%s\n", ".data file detected");

			for (i = 0; i < 1 * samplesToProcess; i++) {
				fseek(file, sizeof(dat) * CHUNK * l, SEEK_CUR);

				temp = 0;
				for (j = 0; j < CHUNK; j++) {
					fread((void*)(&dat), sizeof(dat), 1, file);
					waveDataRead[(i / 1) * CHUNK + j] = (double)(dat);
				if(i==samplesToProcess-1 && j==CHUNK-1){
						printf("wave data %d %f \n",i*CHUNK,  waveDataRead[i*CHUNK + j] );
					}
				}
				
				fseek(file, sizeof(dat) * (total - (CHUNK  * (l + 1))), SEEK_CUR);
			}
		}
		else {
			long int dat;
			fprintf(stderr, "%s\n", ".txt file detected");
			for (i = 0; i < samplesToProcess; i++) {
				for (j = 0; j < WAVELENGTH; j++) {
					fscanf(file, "%d", &dat);
					waveDataRead[i*CHUNK + j] = (double)dat;
					if(i==samplesToProcess-1 && j==WAVELENGTH-1){
						printf("wave data %f \n", waveDataRead[i*CHUNK + j] );
					}
				}
			}
			
		}

		fclose(file);

		unsigned int innerRounds = CHUNK / WAVELENGTH;
		if (CHUNK % WAVELENGTH != 0)
			innerRounds++;
		// main loop
		for (k = 0; k < innerRounds; k++) {
			//get wave data
			double *waveData = (double *)malloc(sizeof(double) * samplesToProcess *  WAVELENGTH);
			isMemoryFull((unsigned int*)waveData);
			unsigned int *cipherText = (unsigned int *)malloc(sizeof(unsigned int) * samplesToProcess * KEYBYTES);
			isMemoryFull(cipherText);

			fprintf(stderr, "%s %d %d %d \n", "Calculating", l, k, innerRounds);

			for (i = 0; i < samplesToProcess; i++) {
				if(memcpy(&waveData[i * WAVELENGTH], &waveDataRead[selection[i] * CHUNK + k * WAVELENGTH], sizeof(double) * WAVELENGTH) == NULL){
					printf("mem cpy failed\n");
				}
				if(memcpy(&cipherText[i * KEYBYTES], &cipherTextRead[selection[i] * KEYBYTES], sizeof(unsigned int) * KEYBYTES) == NULL){
					printf("mem cpy failed\n");
				}
			}
	        free(waveDataRead);
	        free(selection);


			unsigned int *dev_cipherText;
			double *dev_correlation, *dev_waveStat, *dev_waveStat2, *dev_hammingStat, *dev_waveData;
			byte *dev_hammingArray, *dev_hammingArray2;

			if(cudaMalloc((void**)&dev_waveData, 1L * samplesToProcess * WAVELENGTH * sizeof(double)) != cudaSuccess){
				printf("cuda malloc failed wave data \n");
			}
			if(cudaMalloc((void**)&dev_cipherText, 1L * samplesToProcess * KEYBYTES * sizeof(unsigned int)) != cudaSuccess){
				printf("cuda malloc failed ciphertext\n");
			}

			if(cudaMalloc((void**)&dev_hammingArray, 1L * KEYS * KEYBYTES * samplesToProcess * sizeof(byte))!= cudaSuccess){
				printf("cuda malloc failed hamming array\n");
				printf("samples to process %ld \n", 1L* KEYS * KEYBYTES * samplesToProcess);
			}
			unsigned long a =  KEYS * KEYBYTES * sizeof(byte);
			double len_array = 1L * a* samplesToProcess;

			if(len_array > 4294967295){
				cudaMalloc((void**)&dev_hammingArray2, a * samplesToProcess  - 4294967295 );
			}else{
				cudaMalloc((void**)&dev_hammingArray2, 1 );

			}

			if(cudaMalloc((void**)&dev_hammingStat, 2 * KEYS * KEYBYTES * sizeof(double)) != cudaSuccess){
				printf("cuda malloc failed hammingstat");
			}

			
			if(cudaMemcpy(dev_cipherText, cipherText, 1L * samplesToProcess * KEYBYTES * sizeof(unsigned int), cudaMemcpyHostToDevice) != cudaSuccess){
				printf("cuda mem cpy failed\n");
			}
			free(cipherText);

			//find hamming model
			dim3 grid(KEYBYTES / 16, KEYS / 16);
			dim3 block(16, 16);
			hamming_kernel << <grid, block >> > (dev_cipherText, dev_hammingArray, dev_hammingArray2, dev_hammingStat, samplesToProcess);
			cudaGetLastError();
			cudaFree(dev_cipherText);

			//find wave stats
			if(cudaMemcpy(dev_waveData, waveData, 1L * samplesToProcess * WAVELENGTH * sizeof(double), cudaMemcpyHostToDevice) != cudaSuccess){
				printf("cuda mem cpy failed\n");
			}
			printf("wave data %zu", 1L * samplesToProcess * WAVELENGTH * sizeof(double) - 1);
			printf("wave data %zd", 1L * samplesToProcess * WAVELENGTH * sizeof(double) - 1);
			free(waveData);

			if(cudaMalloc((void**)&dev_waveStat, 2 * WAVELENGTH * sizeof(double)) != cudaSuccess){
				printf("cuda malloc failed wave stat\n");
			}
			if(cudaMalloc((void**)&dev_waveStat2, 1L * KEYS * KEYBYTES * WAVELENGTH * sizeof(double)) != cudaSuccess){
				printf("cuda malloc failed wavestat2\n");
			}
			dim3 block3d(16, 16, 4);
			dim3 grid3d(KEYBYTES / 16, KEYS / 16, WAVELENGTH / 4);
			wave_stat_kernel << <grid3d, block3d >> > (dev_waveData, dev_waveStat, dev_waveStat2, dev_hammingArray,dev_hammingArray2, samplesToProcess, WAVELENGTH);
			cudaGetLastError();
			if(cudaFree(dev_waveData)!=cudaSuccess){
				printf("cuda free failed\n");
			}
			if(cudaFree(dev_hammingArray)!=cudaSuccess){
				printf("cuda free failed\n");
			}
			if(cudaFree(dev_hammingArray2)!=cudaSuccess){
				printf("cuda free failed\n");
			}

			//calculate correlation coefficient
			if(cudaMalloc((void**)&dev_correlation, KEYS * KEYBYTES * sizeof(double)) != cudaSuccess){
				printf("cuda malloc failed correlation\n");
			}
			max_correlation_kernel << <grid, block >> > (dev_correlation, dev_waveStat, dev_waveStat2, dev_hammingStat, samplesToProcess, WAVELENGTH);
			//printf("correlation %f\n", dev_correlation[0]);
			//printf("correlation2 %f\n", dev_correlation[KEYS * KEYBYTES - 1]);

			cudaGetLastError();

			//copy back to host and free
			if(cudaMemcpy(correlation, dev_correlation, KEYS * KEYBYTES * sizeof(double), cudaMemcpyDeviceToHost) != cudaSuccess){
				printf("cuda mem cpy failed\n");
			}
			if(cudaFree(dev_correlation)!=cudaSuccess){
				printf("cuda free failed\n");
			}
			if(cudaFree(dev_waveStat) != cudaSuccess){
				printf("cuda free failed\n");
			}
			if(cudaFree(dev_waveStat2)!=cudaSuccess){
				printf("cuda free failed\n");
			}
			if(cudaFree(dev_hammingStat)!=cudaSuccess){
				printf("cuda free failed\n");
			}
			for (i = 0; i < KEYS; i++) {
				for (j = 0; j < KEYBYTES; j++) {
					double maxValue = maxCorrelation[i * KEYBYTES + j];
					double thisIteration = correlation[i * KEYBYTES + j];
					if (maxValue < thisIteration)
						maxCorrelation[i * KEYBYTES + j] = thisIteration;
				}
			}

			//log_correlations_each_iteration(l + innerRounds * k, correlation, samplesToProcess, output_path);
		}

	}
	free(correlation);
	log_maxCorrelation(maxCorrelation, samplesToProcess, samplesToProcess, output_path);

	//log_correlation_known_key_csv(maxCorrelation, ROUNDKEY, output_path);

	double finalCorrelations[KEYS][KEYBYTES];
	int positions[KEYS][KEYBYTES];
	printf("sort\n");
	sort_correlations(finalCorrelations, positions, maxCorrelation);
	printf("sort done\n");
	free(maxCorrelation);

	//log_highest_correlation_csv(finalCorrelations, output_path);

	//log_top_k_correlations(finalCorrelations, positions, 5, output_path);

	//print_top_k_correlations(finalCorrelations, positions, 5);
	
#ifdef MULTIRUN_SUMMARY
	multirun_update_summary(positions, keyByteIndex, ROUNDKEY);
#endif // MULTIRUN_SUMMARY

#ifdef MULTIRUN
	log_correct_keybyte_count_csv(positions, ROUNDKEY, output_path);
#endif // MULTIRUN

	return;
}

__device__ byte hamming_weight(byte M, byte R) {
	byte H = M ^ R;
	// Count the number of set bits
	byte dist = 0;
	while (H) {
		dist++;
		H &= H - 1;
	}
	return dist;
}

//3rd argument n is the index of the key byte
__device__ byte hamming(unsigned int *cipherText, unsigned int sample, unsigned int n, unsigned int key) {
	byte st10 = (byte)cipherText[sample * KEYBYTES + inv_shift[n]];
	byte st9 = (byte)inv_sbox[cipherText[sample * KEYBYTES + n] ^ key];
	byte dist = hamming_weight(st9, st10);
	return dist;
}

__global__ void max_correlation_kernel(double *correlation, double *waveStat, double *waveStat2, double *hammingStat, unsigned int samplesToProcess, int WAVELENGTH) {
		int keyguess = blockDim.y * blockIdx.y + threadIdx.y;
	int keybyte = blockDim.x * blockIdx.x + threadIdx.x;
	
	if (keybyte < KEYBYTES && keyguess < KEYS) {
		double sigmaH, sigmaH2, sigmaW = 0, sigmaW2 = 0, sigmaWH = 0;
		sigmaH = hammingStat[KEYBYTES * keyguess + keybyte];
		sigmaH2 = hammingStat[KEYS * KEYBYTES + KEYBYTES * keyguess + keybyte];
		double correlationTemp = 0;
		double correlationMax = 0;
		unsigned int j;

		for (j = 0; j < WAVELENGTH; j++) {
			sigmaWH = waveStat2[j * KEYS * KEYBYTES + keyguess * KEYBYTES + keybyte];
			sigmaW = waveStat[j];
			sigmaW2 = waveStat[WAVELENGTH + j];
			double numerator = samplesToProcess * sigmaWH - sigmaW * sigmaH;
			double denominator = sqrt(samplesToProcess * sigmaW2 - sigmaW * sigmaW) * sqrt(samplesToProcess * sigmaH2 - sigmaH * sigmaH);
			correlationTemp = fabs(numerator / denominator);

			if (correlationTemp > correlationMax) {
				correlationMax = correlationTemp;
			}
		}
		correlation[keyguess * KEYBYTES + keybyte] = correlationMax;
	}
	return;
}

__global__ void wave_stat_kernel(double *waveData, double *waveStat, double *waveStat2, byte *hammingArray, byte *hammingArray2, unsigned int samplesToProcess, int WAVELENGTH) {
	int keyguess = blockDim.y * blockIdx.y + threadIdx.y;
	int keybyte = blockDim.x * blockIdx.x + threadIdx.x;
	int wave = blockDim.z * blockIdx.z + threadIdx.z;

	if (keyguess < KEYS && keybyte < KEYBYTES && wave < WAVELENGTH) {
		unsigned int i;
		double sigmaWH = 0;
		for (i = 0; i < samplesToProcess; i++) {
			unsigned long a= KEYS * KEYBYTES;
			if((i * a + keyguess * KEYBYTES + keybyte) < 4294967295){
			sigmaWH += waveData[i * WAVELENGTH + wave] * (double)hammingArray[i * a + keyguess * KEYBYTES + keybyte];
			}else{
			sigmaWH += waveData[i * WAVELENGTH + wave] * (double)hammingArray2[(i * a + keyguess * KEYBYTES + keybyte) - 4294967295];
			}
		}
		waveStat2[wave * KEYS * KEYBYTES + keyguess * KEYBYTES + keybyte] = sigmaWH;
	}

	if (keyguess == 0 && keybyte == 0 && wave < WAVELENGTH) {
		unsigned int i;
		double sigmaW = 0, sigmaW2 = 0, W = 0;
		for (i = 0; i < samplesToProcess; i++) {
			W = waveData[i * WAVELENGTH + wave];
			sigmaW += W;
			sigmaW2 += W * W;
		}
		waveStat[wave] = sigmaW;
		waveStat[WAVELENGTH + wave] = sigmaW2;
	}
	return;
}

__global__ void hamming_kernel(unsigned int *cipherText, byte *hammingArray, byte *hammingArray2, double *hammingStat, unsigned int samplesToProcess) {
	int keyguess = blockDim.y * blockIdx.y + threadIdx.y;
	int keybyte = blockDim.x * blockIdx.x + threadIdx.x;

	if (keybyte < KEYBYTES && keyguess < KEYS) {
		double sigmaH = 0, sigmaH2 = 0;
		byte H;
		unsigned int i;
		for (i = 0; i < samplesToProcess; i++) {
			H = hamming(cipherText, i, keybyte, keyguess);
			unsigned long a = KEYS * KEYBYTES;
			if((i *a + keyguess * KEYBYTES + keybyte) < 4294967295){	
			hammingArray[i * KEYS * KEYBYTES + keyguess * KEYBYTES + keybyte] = H;
			}else{
			hammingArray2[(i * a + keyguess * KEYBYTES + keybyte) - 4294967295] = H;
			}
			sigmaH += (double)H;
			sigmaH2 += (double)H * (double)H;
		}
		hammingStat[KEYBYTES * keyguess + keybyte] = sigmaH;
		hammingStat[KEYS * KEYBYTES + KEYBYTES * keyguess + keybyte] = sigmaH2;
	}
	return;
}

void randomize_selection(unsigned int *selection, unsigned int samplesToProcess) {
	srand(time(0));
	unsigned int temp = 0;
	for (int i = 0; i < samplesToProcess; i++) {
		unsigned int swap_i = rand() % samplesToProcess;
		temp = selection[i];
		selection[i] = selection[swap_i];
		selection[swap_i] = temp;
	}
	return;
}

void log_correlations_each_iteration(int iteration, double *correlation, unsigned int samplesToProcess, char output_path[1000]) {
        char file_name[1000];
        snprintf(file_name, sizeof(char) * 1000, "%s/all_kr_" GPUIDXSTR ".txt", output_path);
	FILE *file;
	if (iteration == 0)
		file = fopen(file_name, "w");
	else
		file = fopen(file_name, "a");

	fprintf(file, "%d,  pk0,  pk1,  pk2,  pk3,  pk4,  pk5,  pk6,  pk7,  pk8,  pk9, pk10, pk11, pk12, pk13, pk14, pk15, \n", samplesToProcess);
	for (int i = 0; i < KEYS; i++) {
		fprintf(file, "0x%02X,", i);
		for (int j = 0; j < KEYBYTES; j++) {
			fprintf(file, "%.15f,", i, correlation[i * KEYBYTES + j]);
		}
		fprintf(file, "\n");
	}

	fprintf(file, "\n\n");
	fclose(file);
	return;
}

//Among the multiple iterations, the maximum correlation for each key byte and key guess
void log_maxCorrelation(double *maxCorrelation, unsigned int samplesToProcess, unsigned int file_index, char output_path[1000]) {
  char file_name[1000];
  snprintf(file_name, sizeof(char) * 1000, "%s/final_kr/%i.txt", output_path, file_index);
  
	FILE *file = fopen(file_name, "a");
	for (int i = 0; i < KEYS; i++) {
		for (int j = 0; j < KEYBYTES-1; j++) {
			fprintf(file, "%.15f,", maxCorrelation[i * KEYBYTES + j]);
		}
		fprintf(file, "%.15f\n", maxCorrelation[i * KEYBYTES + KEYBYTES - 1]);
	}
  fclose(file);
	return;
}

void log_correlation_known_key_csv(double *maxCorrelation, int ROUNDKEY[KEYBYTES], char output_path[1000]) {
	//int key[KEYBYTES] = { ROUNDKEY };
	int key[KEYBYTES]; 
        for(int i=0;i<16; i++)
          key[i] = ROUNDKEY[i];

        char file_name[1000];
        snprintf(file_name, sizeof(char) * 1000, "%s/corr_coef_key_kr_" GPUIDXSTR ".csv", output_path);
	FILE *file = fopen(file_name, "a");

	for (int i = 0; i < KEYBYTES; i++) {
		for (int j = 0; j < KEYS; j++) {
			if (key[i] == j) {
				fprintf(file, "%.15f", maxCorrelation[j * KEYBYTES + i]);
				if (i < KEYBYTES - 1)
					fprintf(file, ", ");
			}
		}
	}
	fprintf(file, "\n");
	fclose(file);
	return;
}

void sort_correlations(double finalCorrelations[KEYS][KEYBYTES], int positions[KEYS][KEYBYTES], double *maxCorrelation) {
	double n = 0;
	for (int j = 0; j < KEYBYTES; j++) {
		for (int i = 0; i < KEYS; i++) {
			finalCorrelations[i][j] = maxCorrelation[i * KEYBYTES + j];
			positions[i][j] = i;
		}
		for (int p = 0; p < 255; p++) {
			for (int i = 0; i < KEYS - p - 1; i++) {
				if (finalCorrelations[i][j] < finalCorrelations[i + 1][j]) {
					n = finalCorrelations[i][j];
					finalCorrelations[i][j] = finalCorrelations[i + 1][j];
					finalCorrelations[i + 1][j] = n;

					n = positions[i][j];
					positions[i][j] = positions[i + 1][j];
					positions[i + 1][j] = n;
				}
			}
		}
	}
	return;
}

void log_highest_correlation_csv(double finalCorrelations[KEYS][KEYBYTES], char output_path[1000]) {
        char file_name[1000];
        snprintf(file_name, sizeof(char) * 1000, "%s/corr_coef_highest_kr_" GPUIDXSTR ".csv", output_path);
	FILE *file = fopen(file_name, "a");

	for (int j = 0; j < KEYBYTES; j++) {
		fprintf(file, "%.15f", finalCorrelations[0][j]);
		if (j < KEYBYTES - 1) {
			fprintf(file, ", ");
		}
	}
	fprintf(file, "\n");
	fclose(file);
	return;
}

void log_top_k_correlations(double finalCorrelations[KEYS][KEYBYTES], int positions[KEYS][KEYBYTES], int k, char output_path[1000]) {
	FILE *file;
	char filename[1000];
	char str_k[4];
	sprintf(str_k, "%d", k);
        snprintf(filename, sizeof(char) * 1000, "%s/top_%s_keys.txt", output_path, str_k);
	file = fopen(filename, "a");

	for (int j = 0; j < KEYBYTES; j++) {
		fprintf(file, "  |%02d|\t", j);
	}
	fprintf(file, "\n");

	for (int i = 0; i < k; i++) {
		for (int j = 0; j < KEYBYTES; j++) {
			fprintf(file, "  %02x\t", positions[i][j]);
		}
		fprintf(file, "\n");
		for (int j = 0; j < KEYBYTES; j++) {
			fprintf(file, "%.15f \t", finalCorrelations[i][j]);
		}
		fprintf(file, "\n\n");
	}
	fprintf(file, "\n\n");
	fclose(file);
	return;
}

void print_top_k_correlations(double finalCorrelations[KEYS][KEYBYTES], int positions[KEYS][KEYBYTES], int k) {
	for (int j = 0; j < KEYBYTES; j++) {
		printf("  |%02d|\t", j);
	}
	printf("\n");

	for (int i = 0; i < k; i++) {
		for (int j = 0; j < KEYBYTES; j++) {
			printf("  %02x\t", positions[i][j]);
		}
		printf("\n");
		for (int j = 0; j < KEYBYTES; j++) {
			printf("%.15f \t", finalCorrelations[i][j]);
		}
		printf("\n\n");
	}
	printf("\n\n");
	return;
}

void log_correct_keybyte_count_csv(int positions[KEYS][KEYBYTES], int ROUNDKEY[KEYBYTES], char output_path[1000]) {
	//int key[KEYBYTES] = { ROUNDKEY };
	int key[KEYBYTES]; 
        for(int i=0;i<16; i++)
          key[i] = ROUNDKEY[i];

        char file_name[1000];
        snprintf(file_name, sizeof(char) * 1000, "%s/correct_keybyte_count_kr_" GPUIDXSTR ".csv", output_path);
	FILE *file = fopen(file_name, "a");
	int cnt = 0;
	for (int j = 0; j < KEYBYTES; j++) {
		if (positions[0][j] == key[j])
			cnt++;
	}
	printf("cnt %d \n", cnt);
	fprintf(file, "%d", cnt);
	fclose(file);
	return;
}

void log_misc_string(char *str, char output_path[1000]) {
        char file_name[1000];
        snprintf(file_name, sizeof(char) * 1000, "%s/correct_keybyte_count_kr_" GPUIDXSTR ".csv", output_path);
	FILE *file = fopen(file_name, "a");
	fprintf(file, "%s", str);
	fclose(file);
	return;
}

void multirun_update_summary(int positions[KEYS][KEYBYTES], unsigned int keyByteIndex[KEYBYTES], int ROUNDKEY[KEYBYTES]) {
	//int key[KEYBYTES] = { ROUNDKEY };
	int key[KEYBYTES]; 
        for(int i=0;i<16; i++)
          key[i] = ROUNDKEY[i];

	for (int j = 0; j < KEYBYTES; j++) {
		for (int i = 0; i < KEYS; i++) {
			if (positions[i][j] == key[j])
				keyByteIndex[j] = keyByteIndex[j] + i;
		}
	}
	return;
}

void log_keybyte_summary(int i, unsigned int keyByteIndex[KEYBYTES], char output_path[1000]) {
        char file_name[1000];
        snprintf(file_name, sizeof(char) * 32, "%s/summary_keybyte_kr_" GPUIDXSTR ".csv", output_path);
	FILE *file = fopen(file_name, "a");
	fprintf(file, "%d", i);
	for (int j = 0; j < KEYBYTES; j++) {
		fprintf(file, ", %d", keyByteIndex[j]);
	}
	fprintf(file, "\n");
	fclose(file);
	return;
}

void isMemoryFull(unsigned int *ptr){
	if(ptr == NULL){
		printf("----memory\n");
	}
}
