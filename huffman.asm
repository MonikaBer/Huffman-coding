.data
	msg: 		   .asciiz  "[0] - kodowanie, [1] - dekodowanie. Twoj wybor: "
	msg4:              .asciiz  "Statystyki:\n"
	msg5:              .asciiz  "Ile wczytanych znaków: "
	msg6:              .asciiz  "\nIle rodzajów znaków: "
	fileName: 	   .asciiz   "file1"      #nazwa pliku z tekstem niezakodowanym (początkowego)
	fileName2: 	   .asciiz   "file2"      #nazwa pliku z tekstem zakodowanym przez program
	fileName3: 	   .asciiz   "file3"      #nazwa pliku wyjściowego z tekstek odkodowanym przez program
	array:             .align   2
			   .space   10220     #(2000*2-1)*(20)   (511 elementów typu: (częstość, lewy syn, prawy syn, znak, rodzic) )	
	buffer10: 	   .byte    10 	     #bufor do czytania z pliku
	buffer: 	   .byte    1 	     #bufor do czytania z pliku
	wordBuffer:        .space   4        #bufor do przeczytania liczby znaczących bitów w ostatnim bajcie zakodowanego tekstu
        howManyChars:      .word             #jak dużo rodzajów znaków 
	freqArray:  	   .align   2	     #częstość znaków dopiero wczytanych (będą tu zera na pozycjach znaków które nie wystąpiły)
		      	   .space   1024 	
	byteBufferForCode: .space   255  #bufer dla kodu danego znaku, gdzie każdy bajt odpowiada liczbie '1' lub '0'
	code:              .space   32         # 255b+1b (żeby było do pełnych bajtów, czyli w sumie 32B, bo kod dla 1 znaku) 
		

.text 
main:
	li $v0, 4    
	la $a0, msg
	syscall         #wypisanie komunikatu msg do użytkownika
		
	
	li $v0, 5       #załadowanie 0 lub 1 od użytkownika (kodowanie lub dekodowanie)
	syscall
	
	move $t3, $v0   #decyzja o kod/dekod w $t3	
	bnez $t3, openFileToDecode                #jeśli chcemy dekodować to skaczemy do decode
						
openFileToCode:
	li   $v0, 13       		# otwieramy plik
	la   $a0, fileName    		# nazwa pliku z którego czytamy	
	li   $a1, 0        		# $a1 i $a2 przyjmują 0 dla czytania z pliku (1 byłoby dla zapisu) 
	li   $a2, 0       		
	syscall            		# otwarcie pliku (deskryptor pliku zapisany do $v0)
	move $s0, $v0      		# deskryptor pliku w $s0
	
        # ustawienie rejestrów do czytania z pliku
	move $a0, $s0      		# deskryptor pliku w $a0
	la   $a1, buffer10   		# adres bufora do którego będziemy wprowadzać przeczytany znak z pliku
	li   $a2, 10  		# ustalona długość bufora

	li $t4, 0		#licznik wyzerowany tzn. $t4 zliczania wczytanych znaków
	
readFileLoop:
	li   $v0, 14       		# system call do czytania z pliku
	syscall            		# w $v0 jest liczba przeczytanych znaków
	
	beqz $v0, endReadFileLoop       #jeśli liczba wczytanych z pliku znaków równa się 0 to kończymy, skaczemy do 'endReadFileLoop'
	move $t5, $a1
	
readCharFromBuffer:
#obsłużenie bufora (bieżącego znaku wczytanego z pliku)
	lbu $t1, ($t5)                  #w $t1 jest bieżący znak z tekstu
	mul $t1, $t1, 4                 #zwiększenie adresu z bajtu do 4 bajtów   
	lw $t2, freqArray($t1)          #to co jest w freqArray pod adresem wyznaczonym przez kod ascii umieszczamy w $t2
	addi $t2, $t2, 1                # inkrementujemy wartość w $t2 
	sw $t2, freqArray($t1)          #zapisujemy zmienioną wartość $t2 do freqArray pod ten sam adres co poprzednio
					#w ten sposób dodaliśmy wystąpienie znaku do tablicy ilości poszczególnych znaków 	
	addi $t4, $t4, 1                #inkrementujemy licznik zapisanych na stosie kolejno znaków tekstu
	
	addi $t5, $t5, 1
	subu $t2, $t5, $a1               #liczba już zapisanych znaków do freqArray z bufora 10 bajtowego
	bge $t2, $v0, readFileLoop      #jeśli liczba już zapisanych znaków jest równa liczbie przeczytanych znaków z pliku to skocz
	
	j readCharFromBuffer
	
endReadFileLoop: 
	la $t0, freqArray            #w $t0 jest adres tabeli częstości znaków
	
	li $v0, 4
	la $a0, msg4   
	syscall 
	li $v0, 4
	la $a0, msg5   
	syscall 
	
	li $v0, 1
	move $a0, $t4
	syscall
	
	li $t2, 0             #wyzerowanie $t2 (do zliczania ilości rodzajów znaków)       
	move $t4, $t0             #adres tabeli częstości znaków w $t4
	li $t6, 0            #wyzerowanie $t6 (do chodzenia po array)
#.................................................................................................................................
			
findCharsLoop:                       #wyszukanie rodzajów znaków które wystąpiły w pliku
	lw $t3, ($t0)                #w $t3 adres bieżącego elementu w tablicy częstości znaków
	bnez $t3, writeToArray   #jeśli taki znak wystąpił to skocz do 'writeToArray'
	addi $t0, $t0, 4             #zwiększ $t0 o 4 żeby przechowywało adres kolejnego elementu w tablicy częstości znaków
			
	subu $t5, $t0, $t4           #odejmij od adresu bieżącego elementu w tablicy częstości znaków adres pierwszego elementu w 
	                     #tablicy częstości znaków (w ten sposób w $t5 mamy ilość przejrzanych elementów w tablicy częstości znaków * 4
	                                                                       # - bo każdy element w tablicy ma adres 4 bajtowy) 
	bge $t5, 1024, prepare  #jeśli przejrzeliśmy już całą tablicę częstości znaków to skocz
	j findCharsLoop     #jeśli nie przejrzano jeszcze całej tablicy częstości to powrót do początku pętli
	
writeToArray:
	addi $t2, $t2, 1       
	sw $t3, array($t6) 	      #zapisanie do array częstości bieżącego znaku
	subu $t5, $t0, $t4 		
	                                                                            

	addi $t6, $t6, 4
	sw $zero, array($t6)          #wyzerowanie miejsca dla lewego syna
	addi $t6, $t6, 4
	sw $zero, array($t6)          #wyzerowanie miejsca dla prawego syna	     
	addi $t6, $t6, 4
	sw $t5, array($t6)            #zapisanie znaku   
	addi $t6, $t6, 4           
	sw $zero, array($t6)            #wyzerowanie miejsca dla rodzica       
	
	addi $t6, $t6, 4              #w $t6 adres początku kolejnego węzła w array
	
	addi $t0, $t0, 4             #zwiększ $t0 o 4 żeby było adresem kolejnego elementu w tablicy częstości	
	
	subu $t5, $t0, $t4               #odejmij od adresu bieżącego elementu w tablicy częstości znaków adres pierwszego elementu w 
	              #tablicy częstości znaków (w ten sposób w $t5 mamy ilość przejrzanych elementów w tablicy częstości znaków * 4
	                                                                         # - bo każdy element w tablicy ma adres 4 bajtowy)
	bge $t5, 1024, prepare   #jeśli (liczba przejrzanych znaków * 4) jest większa lub równa od 1024 (czyli jeśli
				             #przejrzeliśmy już całą tablicę częstości znaków) to skocz
	j findCharsLoop                  

prepare:
	sw $t2, howManyChars
	li $v0, 4
	la $a0, msg6   
	syscall 
	li $v0, 1
	lw $a0, howManyChars
	syscall
	

prepareToCreateTree:   #uzupełniamy wartości pól dla niepotrzebnych elementów w array (druga połowa)	
	sw $zero, array($t6)      #wyzerowanie częstości
	addi $t6, $t6, 4
	sw $zero, array($t6)          #wyzerowanie miejsca w array dla lewego syna
	addi $t6, $t6, 4
	sw $zero, array($t6)          #wyzerowanie miejsca w array dla prawego syna	     
	addi $t6, $t6, 4           
	li $t3, 2000
	sw $t3, array($t6)      #zapisanie do array znaku 2000 żeby odróżnić pomocnicze węzły od liści
	addi $t6, $t6, 4  
	sw $zero, array($t6)          #wyzerowanie miejsca dla rodzica

	addi $t6, $t6, 4       #w $t6 adres kolejnego węzła w array
	#ustalenie czy array już uzupełniona
	bge $t6, 10220, setIndexes      
        
	j prepareToCreateTree
 			
setIndexes:
	lw $t8, howManyChars
	subi $t8, $t8, 1
	move $t0, $t8   #index i (ilość wczytanych rodzajów znaków - 1)
	move $t1, $t8   #index j (ilość wczytanych rodzajów znaków - 1)	 
	
#uporządkowanie pierwszej połowy węzłów (podstawowych) i zbudowanie drzewa
buildTree:
	blt $t0, 1, parentForRoot   #jeśli i<1 to wyjdź z pętli

sort:	
	li $t6, 0  
	li $s3, 1   #w $s3 info o tym czy lista jest uporządkowana (1- tak, 0 - nie), na początku zakładamy, że tak 

checkCondition:
	move $t2, $t0 
	mul $t2, $t2, 20     #sortowanie listy do indeksu 20i
	
	ble $t2, 20, checkIfOrdered
	subi $s1, $t2, 20  
	bge $t6, $s1, checkIfOrdered    #jeśli bieżący element jest końcem listy to skocz żeby sprawdzić czy lista jest już uporządkowana				
	
	lw $s4, array($t6)      #częstość bieżącego elem w $s4
	addi $t6, $t6, 20
	lw $s5, array($t6)    #częstość nast elem w $s5
	bge $s4, $s5, checkCondition   #jeśli częstość bieżącego elem jest wieksza równa od częstości następnego elementu to skocz do następnego elementu
	#trzeba zamienić elementy miejscami (zamiana częstości, znaków, synów i (rodziców-???))
	#zamiana częstości
	sw $s4, array($t6)
	subi $t6, $t6, 20
	sw $s5, array($t6)      
        addi $t6, $t6, 12
	#teraz zamiana znaków
        lw $s4, array($t6)      #w $s4 1 znak
	addi $t6, $t6, 20
	lw $s5, array($t6)      #w $s5 2 znak
        sw $s4, array($t6) 
        subi $t6, $t6, 20
        sw $s5, array($t6)
        #zamiana lewych synów
        subi $t6, $t6, 8
        lw $s4, array($t6) 
        addi $t6, $t6, 20     
	lw $s5, array($t6)      
        sw $s4, array($t6)
        subi $t6, $t6, 20
        sw $s5, array($t6)
        #zamiana prawych synów
        addi $t6, $t6, 4
        lw $s4, array($t6)      
        addi $t6, $t6, 20
	lw $s5, array($t6)   
        sw $s4, array($t6) 
        subi $t6, $t6, 20	   
        sw $s5, array($t6)
        #zamiana rodziców
        addi $t6, $t6, 8
        lw $s4, array($t6)      
        addi $t6, $t6, 20
	lw $s5, array($t6)   
        sw $s4, array($t6) 
        subi $t6, $t6, 20	   
        sw $s5, array($t6)
        
        subi $t6, $t6, 16   #powrót do początku bieżacego węzła
             																		 			 																		 																	 			 																																		 			 																		 																	 			 																																			 			 																		 																	 			 																																		 			 																		 																	 			 																	
	li $s3, 0           #zaznaczamy, że lista nie była uporządkowana
	addi $t6, $t6, 20   #następny węzeł  	
	j checkCondition

checkIfOrdered:	
	beq $s3, $zero, sort
	


createProperTree:   
	move $t8, $t0    
	subi $t8, $t8, 1   #i-1
	mul $t8, $t8, 20
	move $t9, $t1    
        addi $t9, $t9, 1   #j+1	
	mul $t9, $t9, 20
	#przerzucenie częstości  
	lw $t7, array($t8)  
	sw $t7, array($t9)
	#przerzucenie lewego syna
	addi $t8, $t8, 4
	addi $t9, $t9, 4
	lw $t7, array($t8)  
	sw $t7, array($t9)
	#przerzucenie prawego syna
	addi $t8, $t8, 4
	addi $t9, $t9, 4
	lw $t7, array($t8)  
	sw $t7, array($t9)
	#przerzucenie znaku
	addi $t8, $t8, 4
	addi $t9, $t9, 4
	lw $t7, array($t8)  
	sw $t7, array($t9)
	#przerzucenie rodzica
	addi $t8, $t8, 4
	addi $t9, $t9, 4
	lw $t7, array($t8)  
	sw $t7, array($t9)
	#sumowanie częstości
	subi $t8, $t8, 16      #20(i-1)
	move $t9, $t0
	mul $t9, $t9, 20       #20i
	lw $s4, array($t8)
	lw $s5, array($t9)
	addu $s4, $s4, $s5
	sw $s4, array($t8)
	#wpisanie '2000' zamiast poprzedniego znaku w pole 'znak' węzła
	addi $t8, $t8, 12
	li $s4, 2000
	sw $s4, array($t8)
	#ustawienie lewego syna
	subi $t8, $t8, 8
	move $s4, $t0
	mul $s4, $s4, 20
	sw $s4, array($t8)        #20i      
	#ustawienie prawego syna
        addi $t8, $t8, 4
        move $s4, $t1
        addi $s4, $s4, 1
	mul $s4, $s4, 20
	sw $s4, array($t8)  #20(j+1)
	#ustawienie rodzica dla lewego syna
	subi $t8, $t8, 4 
	move $s5, $t0
	subi $s5, $s5, 1
	mul $s5, $s5, 20      #20(i-1)
	lw $s4, array($t8)
	addi $s4, $s4, 16
	sw $s5, array($s4)  
	#ustawienie rodzica dla prawego syna
	addi $t8, $t8, 4
	lw $s4, array($t8)
	addi $s4, $s4, 16
	sw $s5, array($s4)

	subi $t0, $t0, 1  #i--
	addi $t1, $t1, 1  #j++
	j buildTree

#wpisanie w pole 'rodzic' dla roota wartość '15000'
parentForRoot:
	li $t6, 0
	addi $t6, $t6, 16
	li $s4, 15000
	sw $s4, array($t6)

#.....................................................................................................................
codeFile:	            	    
#.........................................................................................................................................
	li   $v0, 13       		#otwarcie pliku do którego będzie zapisywany zakodowany tekst
	la   $a0, fileName2     	#nazwa pliku otwieranego
	li   $a1, 1        		#otwarcie w trybie pisania do pliku
	li   $a2, 0        		#to jest nieważne
	syscall            		#w $v0 jest teraz deskryptor pliku
	move $s6, $v0      		#w $s6 jest deskryptor pliku

#najpierw do pliku zostanie zapisane drzewo Huffmana
	move $a0, $s6     	 	#przekazanie deskryptora pliku do $a0
	li   $v0, 15       		#pisanie do pliku
	la $a1, array	
	li $a2, 10220
	syscall			

#zamknięcie pliku fileName1	
	li   $v0, 16       		#zamknięcie pliku z tekstem do zakodowania
	move $a0, $s0      		#deskryptor pliku przekazany do $a0
	syscall   

#czytanie po kolei znaków niezakodowanych
writeCodesToFile:	
	li   $v0, 13       		# otwieramy plik z niezakodowanym tekstem jeszcze raz
	la   $a0, fileName    		# nazwa pliku z którego czytamy	
	li   $a1, 0        		# $a1 i $a2 przyjmują 0 dla czytania z pliku (1 byłoby dla zapisu) 
	li   $a2, 0       		
	syscall            		# otwarcie pliku (deskryptor pliku zapisany do $v0)
	move $s0, $v0      		# deskryptor pliku w $s0
	
	li $s4, 0     #licznik bitów w bieżącym bajcie kodu wyzerowany
	li $s5, 0     #bieżący bajt kodu wyzerowany
	li $s7, 128       #maska do zapisywania bitu na bieżące miejsce w bajcie kodu (na początku 10000000)
	
#...............................
readFile2Loop:	
# ustawienie rejestrów do czytania z pliku
	move $a0, $s0      		# deskryptor pliku w $a0
	la   $a1, buffer   		# adres bufora do którego będziemy wprowadzać przeczytany znak z pliku
	li   $a2,  1   		        # ustalona długość bufora	
	li   $v0, 14       		# system call do czytania z pliku
	syscall            		# w $v0 jest liczba przeczytanych znaków		
				
	beqz $v0, handleLastCurrentByteOfCode     # liczba wczytanych z pliku znaków równa się 0, więc pozostało obsłużyć tylko ostatnią część 
					          # kodu ostatniego znaku
		
#obsłużenie bufora (bieżącego znaku wczytanego z pliku)
	lbu $t1, ($a1)                   #w $t1 jest bieżący znak z tekstu
	mul $t1, $t1, 4                 #zwiększenie adresu z bajtu do 4 bajtów   

	li $t6, 12   #index wskazuje na pierwszy znak w array (czyli na roota)

	li $s1, 0      #licznik długości kodu dla bieżącego znaku
	li $t9, 0      #index roota w array
	
findCharInArray:
	lw $t0, array($t6)           #znak z bieżącego węzła z drzewa
	move $t3, $t6                  # $t3 - indeks węzła nakierowany na znak
	subi $t3, $t3, 12             # $t3 - indeks węzła (nakierowany na początek węzła)
        beq $t0, $t1, getCharCode    #znaleziono węzeł drzewa odpowiadający poszukiwanemu znakowi   			
	addi $t6, $t6, 20
	j findCharInArray		

getCharCode:
	addi $t6, $t6, 4   #$t6 wskazuje na rodzica znaku znalezionego w array
	lw $t4, array($t6)  #$t4 - indeks rodzica
	addi $t4, $t4, 4    #$t4 - wskazuje na lewego syna rodzica
	lw $t5, array($t4)  #$t5 - indeks lewego syna rodzica 
	beq $t3, $t5, writeOne   #węzeł był lewym synem rodzica, trzeba napisać '1' do bufora 'code'
	 
#węzeł był prawym synem rodzica, trzeba napisać '0' do bufora 'code'	
writeZero:
	move $s2, $s1               #bieżący index do zapisu do byteBufferForCode
	addi $s1, $s1, 1    #inkrementacja długości kodu dla bieżącego znaku
	li $s3, 0
	sb $s3, byteBufferForCode($s2)  #zapisanie '0' do byteBufferForCode
	j continueGetCharCode	

writeOne:
	move $s2, $s1              #bieżący index do zapisu do byteBufferForCode
	addi $s1, $s1, 1           #inkrementacja długości kodu dla bieżącego znaku
	li $s3, 1
	sb $s3, byteBufferForCode($s2)  #zapisanie '1' do byteBufferForCode 
			
continueGetCharCode:
	lw $t4, array($t6)  #$t4 - indeks rodzica poprzedniego	
	move $t3, $t4    #poprzedni rodzic to teraz bieżący węzeł (idziemy od liścia do korzenia - w górę drzewa) - chodzi o adres w tablicy
	move $t6, $t4
	beq $t9, $t4, orderByteBufferForCode   #jeśli bieżący węzeł jest rootem to mamy już cały kod dla tego znaku
	addi $t6, $t6, 12
	j getCharCode	

#w tym momencie mamy byteBufferForCode czyli bufor przechowujący kod bieżącego znaku (idąc od liścia do korzenia, a więc na odwrót niż
#chcemy, dlatego trzeba ten odwrócić kolejność bajtów w tym buforze)
orderByteBufferForCode:
	li $s2, 0     #index pierwszego znaczącego elementu w byteBufferForCode
	subi $s3, $s1, 1  #index ostatniego znaczącego elementu w byteBufferForCode

#swap (zamiana wartości na pozycjach $s2 i $s3 w byteBufferForCode)
loopForOrderByteBufferForCode:
	bge $s2, $s3, writeToCode   #kod znaku w byteBufferForCode już jest właściwy, tylko teraz trzeba go zapisać do bufora 
											           # bitowego (czyli do code)
	lbu $t8, byteBufferForCode($s2)   
	lbu $t7, byteBufferForCode($s3)
	sb $t7, byteBufferForCode($s2)
	sb $t8, byteBufferForCode($s3)
	
	addi $s2, $s2, 1
	subi $s3, $s3, 1
	j loopForOrderByteBufferForCode
 	
writeToCode:
	li $s2, 0  #index bieżącego elementu z byteBufferForCode (odpowiadający bieżącemu bitowi znaku, ale wyrażonemu poprzez bajt tzn. '1' lub '0')
	li $s3, 0  #licznik pełnych bajtów kodu bieżącego znaku	
	li $t1, 0  #wyzerowanie indexu dla bufora 'code'
	
loopForWriteToCode:
	bge $s2, $s1, writeCodeForCharToFile2   # już przejrzano cały bufor kodu gdzie '1' i '0' były reprezentowane jako bajty (ostatni bieżący, 
		                                # niepełny bajt pozostał w rejestrze bieżącego bajtu)
	lbu $t0, byteBufferForCode($s2)  #zapisanie elementu z byteBufferForCode (odpowiadającego '1' albo '0')
	beq $t0, 1, writeBiteOne  
	j writeBiteZero
	
writeBiteOne:
	or $s5, $s5, $s7   #zapisanie bitu '1' do bieżącego bajtu kodu
	addi $s2, $s2, 1   #zwiększenie indexu dla byteBufferForCode
	addi $s4, $s4, 1   #zwiększenie ilości bitów w bieżącym bajcie kodu 
	beq $s4, 8, writeByteToCode  #jeśli mamy już cały bajt bieżącego kodu
	srl $s7, $s7, 1  #przesunięcie bitu '1' o 1 w prawo w masce do zapisu kodu dla bieżącego bajtu
	j loopForWriteToCode

writeBiteZero:
	addi $s2, $s2, 1   #zwiększenie indexu dla byteBufferForCode
	addi $s4, $s4, 1   #zwiększenie ilości bitów w bieżącym bajcie kodu 
	beq $s4, 8, writeByteToCode
	srl $s7, $s7, 1  #przesunięcie bitu '1' o 1 w prawo w masce do zapisu kodu dla bieżącego bajtu
	j loopForWriteToCode
	
writeByteToCode:
	addi $s3, $s3, 1   #inkrementacja licznika pełnych bajtów kodu bieżacego znaku
	sb $s5, code($t1)  #zapisanie bieżącego bajtu kodu do bufora 'code' 
	addi $t1, $t1, 1   #zwiększenie indexu dla bufora 'code'
	li $s5, 0      #wyzerowanie bieżącego bajtu kodu dla bieżącego znaku
	li $s4, 0      #wyzerowanie licznika bitów w bieżącym bajcie kodu
	li $s7, 128        #ustawienie maski (ponownie na 10000000)
	j loopForWriteToCode   #powrót do czytania z 'byteBufferForCode' i uzupełniania bieżącego bajtu dla kodu bieżącego znaku
			
# w buforze 'code' mamy kod dla bieżącego znaku, teraz trzeba go zapisać do pliku fileName2
writeCodeForCharToFile2:
	li $t1, 0   #wyzerowany index dla bufora 'code'
	
loopToWriteByteToFile2:
	beq $s3, 0, readFile2Loop  #zapisano już wszystkie pełne bajty kodu bieżącego znaku do pliku fileName2, 
					       #należy wczytać kolejny znak z pliku fileName w celu zakodowania
	move $a0, $s6        #deskryptor pliku fileName2 przekazany do $a0 
	li $a2, 1            #przekazana do $a2 długość zapisywanej części kodu bieżącego znaku (czyli 1B)
	li $v0, 15           #zapis do pliku
	lbu $t3, code($t1)
	li $t2, 0
	sb $t3, buffer($t2)
	
	la $a1, buffer   #przekazany pełny bajt kodu bieżącego znaku do $a1  
	syscall
	
	addi $t1, $t1, 1  #inkrementacja indexu dla 'code'
	subi $s3, $s3, 1  #dekrementacja licznika pełnych bajtów kodu dla bieżącego znaku
	j loopToWriteByteToFile2

handleLastCurrentByteOfCode:
	li $v0, 15          #zapis do pliku
	move $a0, $s6       #deskryptor pliku fileName2 przekazany do $a0 
	li $t1, 0
	sb $s5, code($t1)
	la $a1, code       #przekazany ostatni bieżący bajt kodu bieżącego znaku do $a1
	li $a2, 1         #przekazana do $a2 długość zapisywanej części kodu bieżącego znaku (czyli 1B)	
	syscall

#zapisanie do pliku ilości znaczących bitów w ostatnim bajcie zakodowanego tekstu	
	li $v0, 15                 #pisanie do pliku
	move $a0, $s6     	   #przekazanie deskryptora pliku do $a0	
	
	li $t1, 0
	sb $s4, buffer($t1)
	
	la $a1, buffer            #ilość znaczących bitów w ostatnim bajcie zakodowanego tekstu
	li $a2, 1
	syscall

#zamknięcie otwartych plików
	li   $v0, 16       		#zamknięcie pliku z zakodowanym tekstem
	move $a0, $s6      		#deskryptor pliku przekazany do $a0
	syscall            		
	
	li   $v0, 16       		#zamknięcie pliku z tekstem do zakodowania
	move $a0, $s0      		#deskryptor pliku przekazany do $a0
	syscall            		
	
	j statistics	                #skocz w celu wyświetlenia statystyk
	
#................................................................................................................................................
#dekodowanie (jeśli użytkownik podjął decyzję o dekodowaniu)
openFileToDecode:
	li   $v0, 13       		# otwieramy plik
	la   $a0, fileName2    		# nazwa pliku z którego czytamy (plik z tekstem zakodowanym)	
	li   $a1, 0        		# $a1 i $a2 przyjmują 0 dla czytania z pliku (1 byłoby dla zapisu) 
	li   $a2, 0       		
	syscall            		# otwarcie pliku (deskryptor pliku zapisany do $v0)
	move $s0, $v0      		# deskryptor pliku w $s0
	
#wyzerowanie bufora 'wordBuffer'
	li $t0, 0
	sb $zero, wordBuffer($t0)
	
#należy odczytać drzewo Huffmana zapisane w headerze pliku zakodowanego (zapisanie go do array)
readHeader:
	li $v0, 14
	move $a0, $s0
	la $a1, array
	li $a2, 10220
	syscall
		
#poustawianie rejestrów do chodzenia po drzewie Huffmana (kod kolejnego znaku trzeba odczytać)
	li $t9, 0   #root (jest to index w array który jest początkiem roota)
	li $t6, 0   #index do chodzenia po array (drzewie Huffmana)   
	
#.................................................................................................................................................
#obsłużenie nazwy pliku do zapisu tekstu zdekodowanego
	li   $v0, 13       		#otwarcie pliku do którego będzie zapisywany zdekodowany tekst
	la   $a0, fileName3     	#nazwa pliku otwieranego
	li   $a1, 1        		#otwarcie w trybie pisania do pliku
	li   $a2, 0        		#to jest nieważne
	syscall            		#w $v0 jest teraz deskryptor pliku
	move $s6, $v0      		#w $s6 jest deskryptor pliku

#...................................................................................................................................................
beginReadingCodedText:
#teraz będzie czytany tekst zakodowany z pliku (na początku 3 pierwsze bajty, a potem po jednym bajcie będzie doczytywane)	
	li   $v0, 14     # system call do czytania z pliku
	move $a0, $s0    #przekazanie deskryptora pliku fileName 
	la $a1, buffer   #zmiana bufora do czytania z pliku zakodowanego na 1-bajtowy
	li $a2, 1
	syscall          # w $v0 jest liczba przeczytanych znaków
	beqz $v0, endReadFileToDecode   #nie przeczytano nic
	lbu $s5, ($a1)
	
	
	li   $v0, 14     # system call do czytania z pliku
	move $a0, $s0    #przekazanie deskryptora pliku fileName 
	la $a1, buffer  
	li $a2, 1
	syscall          # w $v0 jest liczba przeczytanych znaków
	lbu $t5, ($a1)

	
#2 pierwsze bajty są odpowiednio w $s5, $t5
	
	
readCodedText:
	move $t0, $s5      #w $t0 bieżący bajt tekstu zakodowanego z pliku
	
#przeczytanie kolejnego bajtu (w celu sprawdzenia czy bieżący bajt nie jest ostatnim)
	li   $v0, 14     # system call do czytania z pliku
	move $a0, $s0    #przekazanie deskryptora pliku fileName 
	la $a1, buffer   
	li $a2, 1
	syscall          # w $v0 jest liczba przeczytanych znaków
	beqz $v0, handleLastCodedByte   #1 bajt tekstu zakodowanego jest zarazem ostatnim bajtem kodu
	#3 pierwsze bajty odpowiednio w  $s5, $t5, $t8
	
	lbu $t8, ($a1)
	move $s5, $t5  #zapisz to co przeczytano w $s5
	move $t5, $t8
	
#obsłużenie wczytanego bajtu tekstu zakodowanego ( w $t0 już jest bieżący bajt tekstu zakodowanego z pliku! )      
	li $s7, 128        #maska do wyciągania bitów z bajtu kodu (na początku 10000000)
	li $t2, 0          #licznik przeczytanych bitów z bieżącego bajtu kodu 
	
loopForCurrentByteOfCode:
	addi $t3, $t6, 12   #przesunięcie indexu żeby wskazywał na pole 'znak' bieżącego węzła
	lw $t4, array($t3)  #pobranie znaku w bieżącym węźle
	bne $t4, 2000, storeByteToResultFile  #doszliśmy do liścia czyli do znaku (w $t4 jest znak)
	
	and $t1, $t0, $s7  #w $t1 jest 0 jeśli bit wskazany przez maskę był '0' lub w $t1 jest coś różnego od zera gdy było '1'
	beqz $t1, goRight
	j goLeft
	
goRight:
	addi $t6, $t6, 8    #index wskazuje na pole węzła w array, w którym jest zapisany adres prawego syna tego węzła		
	lw $t3, array($t6)  #w $t3 jest adres adres (index) w array wskazujący na początek prawego syna
	move $t6, $t3       #$t6 wskazuje na jeden węzeł poniżej (bo dekodując idziemy od korzenia do liścia po drzewie Huffmana)
	
prepareToReadNextBit:
	addi $t2, $t2, 1             #inkrementacja ilości przeczytanych bitów bieżącego bajtu kodu 
	beq $t2, 8, readCodedText    #jeśli przeczytano już cały bajt kodu to skocz w celu pobrania kolejnego zakodowanego bajtu z pliku
	srl $s7, $s7, 1		     #zmień maskę w celu pobrania kolejnego bitu z bajtu zakodowanego
	j loopForCurrentByteOfCode   #skocz w celu wyciągnięcia kolejnego bitu z bajtu zakodowanego
	
goLeft:
	addi $t6, $t6, 4    #index wskazuje na pole węzła w array, w którym jest zapisany adres lewego syna tego węzła
	lw $t3, array($t6)  #w $t3 jest adres adres (index) w array wskazujący na początek lewego syna
	move $t6, $t3       #$t6 wskazuje na jeden węzeł poniżej (bo dekodując idziemy od korzenia do liścia po drzewie Huffmana)	
	j prepareToReadNextBit
	
#zapis znaku zdekodowanego do pliku wynikowego fileName2
storeByteToResultFile:
	li $v0, 15       		#pisanie do pliku
	move $a0, $s6     	 	#przekazanie deskryptora pliku do $a0
	div $t4, $t4, 4
	
	li $t6, 0                  #powrót indexu chodzenia po drzewie do roota
	sb $t4, buffer($t6)
	la $a1, buffer                    #przekazanie znaku do $a1          
	li $a2, 1                       #zapisywanie po 1 bajcie (po jednym zdekodowanym znaku)
	syscall
	
	beq $t2, 8, readCodedText    #jeśli przeczytano już cały bajt kodu to skocz w celu pobrania kolejnego zakodowanego bajtu z pliku
	j loopForCurrentByteOfCode   #skocz w celu wyciągnięcia kolejnego bitu z bajtu zakodowanego
	
handleLastCodedByte:
#w $t0 jest ostatni bajt kodu, a w $t5 jest liczba znaczących bitów w ostatnim bajcie kodu
	li $s7, 128        #maska do wyciągania bitów z bajtu kodu (na początku 10000000)
	li $t2, 0          #licznik przeczytanych bitów z bieżącego bajtu kodu 
	
loopForLastByteOfCode:
	and $t1, $t0, $s7  #w $t1 jest 0 jeśli bit wskazany przez maskę był '0' lub w $t1 jest coś różnego od zera gdy było '1'
	beqz $t1, goRight2
	j goLeft2
	
goRight2:
	addi $t3, $t6, 12   #przesunięcie indexu żeby wskazywał na pole 'znak' bieżącego węzła
	lw $t4, array($t3)  #pobranie znaku w bieżącym węźle
	bne $t4, 2000, storeCharToResultFile  #doszliśmy do liścia czyli do znaku (w $t4 jest znak)
	addi $t6, $t6, 8    #index wskazuje na pole węzła w array, w którym jest zapisany adres prawego syna tego węzła		
	lw $t3, array($t6)  #w $t3 jest adres adres (index) w array wskazujący na początek prawego syna
	move $t6, $t3       #$t6 wskazuje na jeden węzeł poniżej (bo dekodując idziemy od korzenia do liścia po drzewie Huffmana)
	
prepareToReadNextBit2:
	addi $t2, $t2, 1             #inkrementacja ilości przeczytanych bitów ostatniego bajtu tekstu zakodowanego 
	srl $s7, $s7, 1		     #zmień maskę w celu pobrania kolejnego bitu z bajtu zakodowanego
	j loopForLastByteOfCode   #skocz w celu wyciągnięcia kolejnego bitu z ostatniego bajtu zakodowanego
	
goLeft2:
	addi $t3, $t6, 12   #przesunięcie indexu żeby wskazywał na pole 'znak' bieżącego węzła
	lw $t4, array($t3)  #pobranie znaku w bieżącym węzle
	bne $t4, 2000, storeCharToResultFile  #doszliśmy do liścia czyli do znaku (w $t4 jest znak)
	addi $t6, $t6, 4    #index wskazuje na pole węzła w array, w którym jest zapisany adres lewego syna tego węzła
	lw $t3, array($t6)  #w $t3 jest adres (index) w array wskazujący na początek lewego syna
	move $t6, $t3       #$t6 wskazuje na jeden węzeł poniżej (bo dekodując idziemy od korzenia do liścia po drzewie Huffmana)	
	j prepareToReadNextBit2
	
#zapis znaku zdekodowanego do pliku wynikowego fileName2
storeCharToResultFile:
	li $v0, 15       		#pisanie do pliku
	move $a0, $s6     	 	#przekazanie deskryptora pliku do $a0
	
	li $t6, 0 
	div $t4, $t4, 4
	sb $t4, buffer($t6)
	la $a1, buffer                   #przekazanie znaku do $a1          
	li $a2, 1                       #zapisywanie po 1 bajcie (po jednym zdekodowanym znaku)
	syscall
	bne $t2, $t5, loopForLastByteOfCode   #jeśli jeszcze nie przeczytaliśmy wszystkich znaczących bitów w ostatnim bajcie kodu
					      #to skocz do 'loopForLastByteOfCode'
			
endReadFileToDecode:
	li   $v0, 16       		#zamknięcie pliku z zakodowanym tekstem
	move $a0, $s0      		#deskryptor pliku przekazany do $a0
	syscall   
	
	li   $v0, 16       		#zamknięcie pliku z odkodowanym tekstem
	move $a0, $s6      		#deskryptor pliku przekazany do $a0
	syscall          		         		
		                     							    	        	    	    	        	    	    	        	    	    	        	    	    	    
	
		
#wyświetlenie statystyk co do częstości znaków poszczególnych rodzajów
statistics:
        
	li $t0, 0    #licznik wyświetlonych już statystyk dla znaków
	li $t6, 0 
	
	li $v0, 11
	la $a0, '\n'
	syscall
	
	li $v0, 11
	la $a0, '\n'
	syscall		

seekStatistics:
 	addi $t5, $t6, 12
 	lw $t7, array($t5)  #w $t7 jest bieżący znak
 	bne $t7, 2000, aboutChar
 	addi $t6, $t6, 20
 	beq $t6, 10220, exit
 	j seekStatistics
 
 aboutChar:
 	li $v0, 1
	lw $a0, array($t6)       #wyświetlenie częstości bieżącego znaku
	syscall
 
 	li $v0, 11
	li $a0, ' '
	syscall
	
	li $v0, 11
	li $a0, '-'
	syscall
	
	li $v0, 11
	li $a0, ' '
	syscall
 	
 	li $v0, 11
 	div $t7, $t7, 4
 	move $a0, $t7       #wyświetlenie bieżącego znaku 
	syscall		 																																																																																																																																																																																																																																																																																																																																																																																																																											
 			 																																																																																																																																																																																																																																																																																																																																																																																																																											 																																																																																																																																																																																																																																																																																																																																																																																																																											
 	li $v0, 11
	li $a0, '\n'
	syscall		 																																																																																																																																																																																																																																																																																																																																																																																																																											 																																																																																																																																																																																																																																																																																																																																																																																																																											 																																																																																																																																																																																																																																																																																																																																																																																																																											 																																																																																																																																																																																																																																																																																																																																																																																																																											
	
	beq $t6, 10220, exit																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																											
	addi $t6, $t6, 20
 	j seekStatistics 
	
 			
exit:
        li $v0, 10      #koniec programu
	syscall 










