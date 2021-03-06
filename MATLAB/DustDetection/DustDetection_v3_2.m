classdef DustDetection_v3_2
    properties
        %HPF filter
        Filter = [-1 -1 -1
            -1 9 -1
            -1 -1 -1];
        %Threshold
        diff = 40;
        %median filter size
        medi_size = 5;
    end
    methods
        %seperate image dust
        function [merged, medi, gray] = seperate_dust(obj,original_img,medi_size)
            
            if ~exist('medi_size','var')
                medi_size = obj.medi_size;
            end
            
            %A_denoised = imnlmfilt(original_img,'DegreeOfSmoothing',10,'ComparisonWindowSize',7);
            A_denoised = original_img;
            
            A = rgb2gray(A_denoised);
            A_medi = medfilt2(A,[medi_size medi_size]);
            A_sub = A - A_medi;
            A_subinv = A_medi - A;
            A_merged = A_sub + A_subinv;
            
            merged = A_merged;
            medi = A_medi;
            gray = A;
        end
        % thresholding image
        function resultImg = thresholding(obj, img, diff)
            if ~exist('diff','var')
                diff = obj.diff;
            end
            
            resultImg = boolean(zeros(size(img)));
            for i=1:1:size(img,1)
                for j=1:1:size(img,2)
                    px = img(i,j);
                    if (px<diff)
                        resultImg(i,j) = false;
                    else
                        resultImg(i,j) = true;
                    end
                end
            end
        end
       
  function [final_pos, final_pos_struct, all_pos, radius] = mean_shift(obj,image,verseg,horseg,radius,dead_dist)
            all_pos = {};
            
            
            
            im_size = size(image);
            ver = im_size(1);
            hor = im_size(2);
            
            verList = round((1:1:verseg) * (ver/verseg));
            horList = round((1:1:horseg) * (hor/horseg));
            
            all_centroids = [];
            points = cell(size(verList,2)-1, size(horList,2)-1);
            
            % radious auto
            if radius < 0
               radius = sqrt((verList(1) - verList(2))^2 + (horList(1) - horList(2))^2);
            else
               radius = radius; 
            end
            
            
            for i= 1:1:size(verList,2)-1
                for j=1:1:size(horList,2)-1
                    a = [];
                    a.centroid = [verList(i) horList(j)];
                    a.next_centroid = [];
                    a.dotcount = 0;
                    a.isMinimum = false;
                    points{i,j} = a;
                    all_centroids = [all_centroids [a.centroid(1);a.centroid(2);a.isMinimum]];
                end
            end
            all_pos{size(all_pos,2)+1} = all_centroids;
            
            
            % start main loop
            done = false;
            while done==false
                
                done = true;
                all_centroids = [];
                
                % move all centroids new position
                for i= 1:1:size(verList,2)-1
                    for j=1:1:size(horList,2)-1
                        
                        cur_point = points{i,j};
                        
                        % if point is dead, won't move
                        if(cur_point.isMinimum == true)
                            all_centroids = [all_centroids [cur_point.centroid(1);cur_point.centroid(2);cur_point.isMinimum]];
                            continue
                        else
                            done = false;
                        end
                        
                        % get calculation square
                        temp_y = [cur_point.centroid(1) - radius cur_point.centroid(1) + radius];
                        temp_x = [cur_point.centroid(2) - radius cur_point.centroid(2) + radius];
                        
                        for k=1:1:2
                            if temp_y(k) < 1
                                temp_y(k) = 1;
                            elseif temp_y(k) > ver
                                temp_y(k) = ver;
                            end
                        end
                        temp_y = round(temp_y);
                        
                        for k=1:1:2
                            if temp_x(k) < 1
                                temp_x(k) = 1;
                            elseif temp_x(k) > hor
                                temp_x(k) = hor;
                            end
                        end
                        temp_x = round(temp_x);
                        
                        % see calculation square inside
                        dots = [];

                        for ii=temp_y(1):1:temp_y(2)
                            for jj=temp_x(1):1:temp_x(2)
                                % if a dot distance is smaller dist that radious,
                                % insert to points buffer
                                if(image(ii,jj) > 0)
                                    dist = sqrt((cur_point.centroid(1) - ii)^2 + (cur_point.centroid(2) - jj)^2);
                                    
                                    if(dist <= radius)
                                        dots = [dots [ii;jj]];
                                    end   
                                    
                                end
                                
                            end
                        end
                        
                        % calc new mean centroid point with dots
                        if(size(dots,2) >=1)
                            sum_y = sum(dots(1,:));
                            sum_x = sum(dots(2,:));
                            dotcount = size(dots,2);
                            
                            cur_point.next_centroid = [sum_y/dotcount sum_x/dotcount];
                            cur_point.dotcount = dotcount;
                        else
                            cur_point.next_centroid = cur_point.centroid;
                        end
                        
                        % check if this point is dead
                        move_dist = sqrt((cur_point.centroid(1)-cur_point.next_centroid(1))^2 + (cur_point.centroid(2)-cur_point.next_centroid(2))^2);
                        if(move_dist <= dead_dist)
                            cur_point.isMinimum = true;
                        end
                        
                        cur_point.centroid = cur_point.next_centroid;
                        
                        points{i,j} = cur_point;
                        all_centroids = [all_centroids [cur_point.centroid(1);cur_point.centroid(2);cur_point.isMinimum]];
                    end
                end
                
                all_pos{size(all_pos,2)+1} = all_centroids;
                final_pos = all_centroids;
                final_pos_struct = points;
            end
            
            
        end
        
        function [maximum_density, maximum_density_dots] = get_maximum_dustDensity_withMeanShift(obj, point_structs, radius, image, isVisualize)
            
            [x,y] = size(point_structs);
            densities = [];
            
            for i=1:1:x
                for j=1:1:y
                    if(point_structs{i,j}.dotcount < 1)
                        continue;
                    else
                        a = [];
                        a = [a point_structs{i,j}.centroid];
                        a = [a point_structs{i,j}.dotcount/(radius*radius*pi)];
                        a = [a radius];
                        densities = [densities; a];
                    end
                    
                end
            end
            
            T = array2table(densities,'VariableNames',{'dot_x','dot_y','density','radius'});
            T_sorted = sortrows(T,3,'descend');
            
            table_size = size(T_sorted,1);
            target_size = int32(table_size / 50);
            
            maximum_density_dots = table2array(T_sorted(1:target_size,:));
            maximum_density = mean(maximum_density_dots(:,3));
            
            if(isVisualize)
                
                dots = table2array(T_sorted(:,1:2));
                dots = dots';
                
                figure(98);
                hold off;
                imshow(image);
                hold on;
               
                plot(dots(2,(target_size+1):end), dots(1,(target_size+1):end),'g*');
                plot(dots(2,1:target_size), dots(1,1:target_size),'b*');
                
                for i=1:1:target_size
                    viscircles([dots(2,i), dots(1,i)],radius,'LineWidth',1,'LineStyle','-');
                end
            end
            

            
        end
        
        
        % to visualize mean shift result
        function a = visualize_mean_shift(obj,binary_image,centroids_hist,radius,frame_sec,circle_available)
            hist_count = size(centroids_hist,2);
            
            figure(99)
            for i=1:1:hist_count
                cur_centroids = centroids_hist{i};
                alive_points = [];
                dead_points=[];
                
                
                % seperate dead and alive points
                for j=1:1:size(cur_centroids,2)
                    % alive
                    if(cur_centroids(3,j) == 0)
                        alive_points = [alive_points cur_centroids(1:2,j)];
                    else
                        dead_points = [dead_points cur_centroids(1:2,j)];
                    end
                end
                hold off;
                imshow(binary_image);
                hold on;
                
                if(size(dead_points,2) > 0)
                    plot(dead_points(2,:),dead_points(1,:),'*g');
                    
%                     if(circle_available == true)
%                         for k=1:1:size(dead_points,2)
%                             viscircles([dead_points(2,k) dead_points(1,k)],radius,'LineWidth',1,'LineStyle','-','Color','g');
%                         end
%                     end
                end
                
                if(size(alive_points,2) > 0)
                    plot(alive_points(2,:),alive_points(1,:),'*r');
                    
                    if(circle_available == true)
                        for k=1:1:size(alive_points,2)
                            viscircles([alive_points(2,k) alive_points(1,k)],radius,'LineWidth',1,'LineStyle','-','Color','r');
                        end
                    end
                end        
                
                
                
                %save to gif file
                frame = getframe(99);
                img = frame2im(frame);
                [imind cm] = rgb2ind(img,256);
                filename = "mean_shift_������.gif";
                
                if i==1
                    imwrite(imind,cm,filename,'gif','DelayTime',0.25,"LoopCount",inf);
                else
                    imwrite(imind,cm,filename,'WriteMode','append');
                end
                
                pause(frame_sec);
            end
            
        end
        
        
    
        function [ref, refs] = calc_dustRef(obj, refImages_cell)
            cell_count = size(refImages_cell,2);
            
            total_density = [];
            for c = 1:1:cell_count
                ref_density = 0;
                
                [y_axis, x_axis] = size(refImages_cell{c,1});
                ref_pixels = y_axis * x_axis;
                ref_dusts = 0;
                
                cur_image = refImages_cell{c,1};
                figure(97);
                imshow(cur_image);
               for i = 1:1:size(cur_image,1)
                  for j= 1:1:size(cur_image,2) 
                      if (cur_image(i,j) > 0)
                         ref_dusts = ref_dusts + 1;
                      end
                  end
               end
               
               ref_density = ref_dusts / ref_pixels;
               total_density = [total_density ref_density];
            end
            
            ref = mean(total_density);
            refs = total_density;
            
        end
        
    end
end