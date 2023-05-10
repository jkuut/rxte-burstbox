#script to compress data dirs inside burst folders

burst_compress = true #decompress burst folders
data_compress = false #compress data folders (PXXXXX)!!!

lzoname = "proc_sum_fit.tar.lzo"

good_sources = [#"1M0836-425",
#                "3A1820_303",
#                "4U0513-40",
#                "4U1608_52",
#                "4U1636_536",
#                "4U1702_429",
#                "4U1705_44",
#                "4U1724_307",
#                "4U1728_34",
#                "4U1735_44",
#                "4U1746_37",
#                "4U1850-08",
#                "AqlX_1",
#                "EXO0748_676",
#                "GX3+1",
                "HETEJ19001_2455",
#                "J17473-2721",
#                "KS1731_260",
#                "SAXJ1747.9-2853",
#                "SAXJ1748.9_2021",
#                "SAXJ1750.8_2900",
#                "SAXJ1808.4_3658",
#                "SAXJ1810.8-2609",
#                "SLX1744-300",
#                "XTE1810-189",
#                "XTEJ1814-338",
#               "XTEJ2123_058"
		 ]

#all sources
root = pwd()
sources = readdir()

#pick one / or build a loop over all
for source in sources
    if source in good_sources

        println(source)
        #continue        
        #source = sources[6]

        #inside source dir
        cd(root)
        cd(source)
        root_source = pwd()
        
        ############
        # first part of burst file compression
        if burst_compress 
            println("Compressing burst folders...")
            
            
            folders = readdir()
            bfolders = String[]
            for f in folders
                if ismatch(r"\S+-\S+-\S+-\S+_\S+", f)
                    push!(bfolders, f)
                end
            end
            

            #Foreach burst folder
            tic()
            for bf in bfolders
                cd(bf)
                println(bf)
                
                eval(parse("run(`tar xvf $(lzoname)`)")) 

                cd(root_source)
            end
            toc()
            
            
        end #end over burst compress
        


        ###############
        # compres data files
        if data_compress
            println("Compressing data folders...")
            
            folders = readdir()
            dfolders = String[]
            for f in folders
                if ismatch(r"^P\d+$", f)
                    push!(dfolders, f)
                end
            end
            
            
            #Foreach burst folder
            for df in dfolders
                tic()
                println(df)

                cd(df)
                
                pxx_folders = readdir()
                for pxx_f in pxx_folders
                    println(pxx_f)
                    #zip
                    eval(parse("run(`tar -caf $(pxx_f).tar.lzo $(pxx_f)`)"))
                
                    #split if over gigabyte
                    #if stat("$(df).tar.lzo").size > 0
                    #    #val(parse("run(`split -b 1014MiB $(pxx_f)`)"))
                    #end
    
                    #exit()
                    #remove dirs after zipping is complete
                    if stat("$(pxx_f).tar.lzo").size > 0
                        eval(parse("run(`rm -r $(pxx_f)`)"))
                    end

                end
                toc()
                
                cd(root_source)
            end
            #exit()
        end #end over data compress
        
    end #end over if good_source
end #end over loop in sources
