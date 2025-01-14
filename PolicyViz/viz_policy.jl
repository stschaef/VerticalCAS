export viz_policy, viz_grid

using Printf

function viz_policy(nnet_folder::AbstractString="",table_folder::AbstractString="",vnum::Int64=4, hu::Int64=45, epoch::Int64=200)
    # Make sure one of the folder paths is given
    if nnet_folder=="" && table_folder==""
        println("Need at least either a valid nnet or table folder path!")
        return
    end
    
    # Important variables
    currentPra = -1
    nnet = []
    policy = []
    grid = RectangleGrid(relhs,dh0s,dh1s,taus)
    
    # Colors
    ra1 = RGB(1.,1.,1.) # white
    ra2 = RGB(.0,1.0,1.0) # cyan
    ra3 = RGB(144.0/255.0,238.0/255.0,144.0/255.0) # lightgreen
    ra4 = RGB(30.0/255.0,144.0/255.0,1.0) # dodgerblue
    ra5 = RGB(0.0,1.0,.0) # lime
    ra6 = RGB(0.0,0.0,1.0) # blue
    ra7 = RGB(34.0/255.0,139.0/255.0,34.0/255.0) # forestgreen
    ra8 = RGB(0.0,0.0,128.0/255.0) # navy
    ra9 = RGB(0.0,100.0/255.0,0.0) # darkgreen
    colors = [ra1;ra2;ra3;ra4;ra5;ra6;ra7;ra8;ra9]
    bg_colors = [RGB(1.0,1.0,1.0)]
    
    # Create scatter plot classes for color key
    # sc_string = "{"
    # for i=1:9
    #     # define_color("ra$i",  colors[i])
    #     if i==1
    #         sc_string *= "ra$i={mark=square, style={black, mark options={fill=ra$i}, mark size=6}},"
    #     else
    #         sc_string *= "ra$i={style={ra$i, mark size=6}},"
    #     end
    # end
    
    # # Color key as a scatter plot
    # sc_string=sc_string[1:end-1]*"}"
    # xx = [-1.5,-1.5,-1.5, -1.5, -1.5, -1.5, -1.5, 0.4 ,.4,]
    # yy = [1.65,1.15,0.65, 0.15, -0.35, -0.85, -1.35, 1.65, 1.15]
    # zz = ["ra1","ra2","ra3","ra4","ra5","ra6","ra7","ra8","ra9"]
    # sc = string(sc_string)

    # Set up interactive display
    @manipulate for nbin = 100,
        savePlot = [false,true],
        xmin = 0.0,
        xmax = 40.0,
        ymin = -1000.0,
        ymax = 1000.0,
        dh0 = 0.0, 
        dh1 = 0.0, 
        pra = action_names
        
        # Get previous RA index
        pra = findall(pra.==action_names)[1]
        if pra != currentPra
            if table_folder !=""
                alpha = h5open(@sprintf("%s/VertCAS_TrainingData_v2_%02d.h5",table_folder,pra), "r") do file
                    read(file, "y")
                end
                alpha = alpha';
                policy = read_policy(reshape(actions,(1,9)), alpha)
            end
            
            if nnet_folder != "" 
                if epoch>0
                    nnet = NNet(@sprintf("%s/VertCAS_pra%02d_v%d_%dHU_%03d.nnet",nnet_folder,pra,vnum,hu,epoch))
                else
                    nnet = NNet(@sprintf("%s/VertCAS_pra%02d_v%d_%dHU.nnet",nnet_folder,pra,vnum, hu))
                end
            end
            currentPra = pra
        end
        
        # Evaluate network at pixel points
        if nnet_folder != ""
            inputsNet = hcat([[relh,dh0,dh1,tau] for tau=range(xmin, xmax,length=nbin) for relh=range(ymin,ymax,length=nbin)]...)
            q_nnet = evaluate_network_multiple(nnet,inputsNet)
        end
        
        # Q Table Heat Map
        function get_heat1(x::Float64, y::Float64)
            tau = x 
            relh = y
            qvals = evaluate(policy, get_belief([relh,dh0,dh1,tau],grid,false))
            return actions[argmax(qvals)]
        end # function get_heat1
        
        ind = 1
        #Neural Net Heat Map
        function get_heat2(x::Float64, y::Float64)                        
            qvals = q_nnet[:,ind]
            ind +=1
            return actions[argmax(qvals)]
        end # function get_heat2
        
        #Plot table or neural network policies if possible

        numPlots = 3
        numPlots = nnet==nothing ? numPlots-1 : numPlots
        
        g = GroupPlot(numPlots, 1, style="height={8cm}, width={8cm}",groupStyle = "horizontal sep=2cm")   
        
        if table_folder!=""
            push!(g, Axis([
                Plots.Image(get_heat1, (xmin, xmax), (ymin, ymax), zmin = 1, zmax = 9,
                xbins = nbin, ybins = nbin, colormap = ColorMaps.RGBArrayMap(colors), colorbar=false),
                # xbins = nbin, ybins = nbin),
                ], xmin=xmin, xmax=xmax, ymin=ymin,ymax=ymax, width="10cm", height="8cm", 
                   xlabel="Tau (s)", ylabel="Relative Alt (ft)", title="Original Table Advisories"))
        end
        if nnet_folder!=""
            push!(g, Axis([
                Plots.Image(get_heat2, (xmin, xmax), (ymin, ymax), zmin = 1, zmax = 9, 
                            xbins = nbin, ybins = nbin, colormap = ColorMaps.RGBArrayMap(colors), colorbar=false), 
                            # xbins = nbin, ybins = nbin), 
                            ], xmin=xmin, xmax=xmax, ymin=ymin,ymax=ymax,width="10cm", height="8cm", 
                   xlabel="Tau (s)", ylabel="Relative Alt (ft)", title="Neural Network Advisories"))
        end
             
        # Save policy to a tex file to be used in papers
        # if savePlot
        #     PGFPlots.save("PolicyPlot.tex", g, include_preamble=true)
        # else
                            
        # Create Color Key
        f = (x,y)->x # Dummy function for background white image
        push!(g, Axis([
            Plots.Image(f, (-2,2), (-2,2),colormap = ColorMaps.RGBArrayMap(bg_colors),colorbar=false),
            Plots.Image(f, (-2,2), (-2,2)),
            # Plots.Scatter(xx, yy, zz, scatterClasses=sc),
            # Plots.Scatter(xx, yy, zz),
            Plots.Node("RA 1: COC ",0.15,0.915,style="black,anchor=west", axis="axis description cs"),
            Plots.Node("RA 2: DNC ",0.15,0.790,style="black,anchor=west", axis="axis description cs"),
            Plots.Node("RA 3: DND",0.15,0.665,style="black,anchor=west", axis="axis description cs"),
            Plots.Node("RA 4: DES15000",0.15,0.540,style="black,anchor=west", axis="axis description cs"),
            Plots.Node("RA 5: CL1500 ",0.15,0.415,style="black,anchor=west", axis="axis description cs"),
            Plots.Node("RA 6: SDES1500",0.15,0.290,style="black,anchor=west", axis="axis description cs"),
            Plots.Node("RA 7: SCL1500",0.15,0.165,style="black,anchor=west", axis="axis description cs"),
            Plots.Node("RA 8:  SDES2500",0.63,0.915,style="black,anchor=west", axis="axis description cs"),
            Plots.Node("RA 9:  SCL2500",0.63,0.790,style="black,anchor=west", axis="axis description cs"),
            ],width="10cm",height="8cm", hideAxis =true, title="KEY"))
    end
end 